import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rover_model.dart';

class RoverProvider extends ChangeNotifier {
  ConnectionType _connectionType = ConnectionType.none;
  String _wifiIP = '192.168.4.1';
  BluetoothDevice? _bluetoothDevice;
  BluetoothConnection? _bluetoothConnection;
  StreamSubscription<Uint8List>? _bluetoothInputSub;
  String _bluetoothTextBuffer = '';

  String? _activeSessionId;
  String? _activeFarmId;

  double? _btGpsLatitude;
  double? _btGpsLongitude;
  double? _btGpsAltitude;
  double? _btGpsSpeedMps;
  double? _btGpsCourse;
  int? _btGpsSatellites;
  double? _btGpsHdop;
  bool? _btGpsIsValid;

  RoverStatus _status = RoverStatus.disconnected;
  RoverInfo? _info;
  GPSData _gpsData = GPSData.invalid;

  bool _isConnected = false;
  bool _isConnecting = false;
  String _connectionMessage = 'Disconnected';

  Timer? _statusTimer;
  Timer? _reconnectTimer;
  Timer? _gpsTimer;

  SharedPreferences? _prefs;

  ConnectionType get connectionType => _connectionType;
  String get wifiIP => _wifiIP;
  BluetoothDevice? get bluetoothDevice => _bluetoothDevice;
  RoverStatus get status => _status;
  RoverInfo? get info => _info;
  GPSData get gpsData => _gpsData;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get connectionMessage => _connectionMessage;

  String? get activeSessionId => _activeSessionId;
  String? get activeFarmId => _activeFarmId;

  RoverProvider() {
    unawaited(loadPreferences());
  }

  Future<void> loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _wifiIP = _prefs!.getString('rover_wifi_ip') ?? '192.168.4.1';
    _activeSessionId = _prefs!.getString('rover_session_id');
    _activeFarmId = _prefs!.getString('rover_farm_id');
    notifyListeners();
  }

  Future<void> savePreferences() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString('rover_wifi_ip', _wifiIP);
    
    if (_activeSessionId != null) {
      await prefs.setString('rover_session_id', _activeSessionId!);
    } else {
      await prefs.remove('rover_session_id');
    }

    if (_activeFarmId != null) {
      await prefs.setString('rover_farm_id', _activeFarmId!);
    } else {
      await prefs.remove('rover_farm_id');
    }
  }

  void setWifiIP(String ip) {
    _wifiIP = ip.trim();
    unawaited(savePreferences());
    notifyListeners();
  }

  void setActiveSession(String sessionId, String farmId) {
    _activeSessionId = sessionId;
    _activeFarmId = farmId;
    unawaited(savePreferences());
    notifyListeners();
  }

  void clearSession() {
    _activeSessionId = null;
    _activeFarmId = null;
    unawaited(savePreferences());
    notifyListeners();
  }

  Future<bool> connectWiFi() async {
    if (_isConnecting) return false;

    // If we're already connected via WiFi, don't disconnect/reconnect (that causes flapping).
    if (_isConnected && _connectionType == ConnectionType.wifi) {
      return true;
    }

    // If connected via another transport, reset first.
    if (_isConnected) {
      disconnect();
    }

    _connectionType = ConnectionType.wifi;
    _isConnecting = true;
    _connectionMessage = 'Connecting via WiFi...';
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse('http://$_wifiIP/api/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _status = RoverStatus.fromJson(data).copyWith(source: 'wifi');

        _isConnected = true;
        _connectionMessage = 'Connected via WiFi';

        await fetchSystemInfo();
        startStatusPolling();
        unawaited(fetchGPSData());
        startGPSPolling();  // Start GPS polling on WiFi connect

        _isConnecting = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}

    _isConnected = false;
    _connectionMessage = 'WiFi connection failed';
    _connectionType = ConnectionType.none;
    _isConnecting = false;
    notifyListeners();
    return false;
  }

  Future<List<BluetoothDevice>> scanBluetoothDevices() async {
    try {
      final connectStatus = await Permission.bluetoothConnect.status;
      if (!connectStatus.isGranted) {
        final requested = await Permission.bluetoothConnect.request();
        if (!requested.isGranted) {
          _connectionMessage = 'Bluetooth permission denied';
          notifyListeners();
          return [];
        }
      }

      final scanStatus = await Permission.bluetoothScan.status;
      if (!scanStatus.isGranted) {
        await Permission.bluetoothScan.request();
      }

      await FlutterBluetoothSerial.instance.requestEnable();
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  Future<bool> connectBluetooth(BluetoothDevice device) async {
    if (_isConnecting) return false;

    if (_isConnected) {
      disconnect();
    }

    // Ensure permissions + adapter enabled before connecting (Android 12+).
    try {
      final connectStatus = await Permission.bluetoothConnect.status;
      if (!connectStatus.isGranted) {
        final requested = await Permission.bluetoothConnect.request();
        if (!requested.isGranted) {
          _connectionMessage = 'Bluetooth permission denied';
          notifyListeners();
          return false;
        }
      }

      await FlutterBluetoothSerial.instance.requestEnable();
    } catch (_) {}

    _connectionType = ConnectionType.bluetooth;
    _bluetoothDevice = device;
    _isConnecting = true;
    _connectionMessage = 'Connecting via Bluetooth...';
    notifyListeners();

    try {
      // Some devices/ROMs can take longer to complete the SPP socket connect.
      // Retry once after a longer timeout before failing.
      try {
        _bluetoothConnection = await BluetoothConnection.toAddress(device.address)
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        try {
          _bluetoothConnection?.dispose();
        } catch (_) {}
        _bluetoothConnection = null;

        _bluetoothConnection = await BluetoothConnection.toAddress(device.address)
            .timeout(const Duration(seconds: 20));
      }

      _isConnected = true;
      _connectionMessage = 'Connected via Bluetooth';

      _bluetoothInputSub?.cancel();
      _bluetoothInputSub = _bluetoothConnection!.input!.listen((data) {
        final response = utf8.decode(data, allowMalformed: true);
        processBluetoothResponse(response);
      });

      sendBluetoothCommand('status');
      unawaited(fetchGPSData());
      startGPSPolling();

      _isConnecting = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      // If the connection attempt hangs, make sure we cleanup so retries work.
      disconnect();
      _connectionMessage =
          'Bluetooth connection failed: timeout (make sure the rover is paired in Android Bluetooth settings and not already connected to another phone)';
      _isConnecting = false;
      notifyListeners();
      return false;
    } on PlatformException catch (e) {
      // Android socket errors are often surfaced as PlatformException.
      disconnect();
      _connectionMessage = _friendlyBluetoothConnectError(e);
      _isConnecting = false;
      notifyListeners();
      return false;
    } catch (e) {
      // Cleanup any partially-open connection/subscriptions.
      disconnect();
      _connectionMessage = _friendlyBluetoothConnectError(e);
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  String _friendlyBluetoothConnectError(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('timeout')) {
      return 'Bluetooth connection failed: timeout. Pair the rover in Android Bluetooth settings, keep it close, and ensure it is not connected to another phone.';
    }

    if (msg.contains('read failed') ||
        msg.contains('socket might closed') ||
        msg.contains('socket might closed') ||
        msg.contains('socket closed') ||
        msg.contains('read ret: -1')) {
      return 'Bluetooth connection failed: socket closed by Android. Fix: Unpair ESP32_Rover_BT, reboot the rover, toggle Bluetooth OFF/ON, then pair again and retry. Also ensure no other phone is connected to the rover.';
    }

    if (msg.contains('connect_error') || msg.contains('connect failed')) {
      return 'Bluetooth connection failed: could not open SPP connection. Fix: Pair the rover first, keep it close, and ensure it is not connected to another phone.';
    }

    return 'Bluetooth connection failed. Fix: Pair the rover in Android Bluetooth settings, keep it close, and ensure it is not connected to another phone.';
  }

  void processBluetoothResponse(String response) {
    _bluetoothTextBuffer += response;

    while (true) {
      final idx = _bluetoothTextBuffer.indexOf('\n');
      if (idx < 0) break;

      final line = _bluetoothTextBuffer.substring(0, idx).trim();
      _bluetoothTextBuffer = _bluetoothTextBuffer.substring(idx + 1);
      if (line.isEmpty) continue;
      _handleBluetoothLine(line);
    }
  }

  void _handleBluetoothLine(String line) {
    if (line.startsWith('STATUS:')) {
      try {
        final parts = line.split(':');
        if (parts.length >= 3) {
          final cmd = parts[1];
          final speed = int.tryParse(parts[2]) ?? _status.speed;
          _status = _status.copyWith(
            command: cmd,
            direction: cmd,
            isMoving: cmd != 'stop' && cmd != 's',
            speed: speed,
            source: 'bluetooth',
          );
          notifyListeners();
        }
      } catch (_) {}
      return;
    }

    if (line.startsWith('Status:')) {
      _btGpsIsValid = line.contains('VALID');
      _updateGpsFromBtScratch();
      return;
    }
    if (line.startsWith('Latitude:')) {
      _btGpsLatitude = double.tryParse(line.split(':').last.trim());
      _updateGpsFromBtScratch();
      return;
    }
    if (line.startsWith('Longitude:')) {
      _btGpsLongitude = double.tryParse(line.split(':').last.trim());
      _updateGpsFromBtScratch();
      return;
    }
    if (line.startsWith('Altitude:')) {
      final raw = line.split(':').last.trim().split(' ').first;
      _btGpsAltitude = double.tryParse(raw);
      _updateGpsFromBtScratch();
      return;
    }
    if (line.startsWith('Speed:')) {
      final raw = line.split(':').last.trim().split(' ').first;
      final kmh = double.tryParse(raw);
      if (kmh != null) {
        _btGpsSpeedMps = kmh / 3.6;
      }
      _updateGpsFromBtScratch();
      return;
    }
    if (line.startsWith('Course:')) {
      final raw = line.split(':').last.trim().replaceAll('°', '').split(' ').first;
      _btGpsCourse = double.tryParse(raw);
      _updateGpsFromBtScratch();
      return;
    }
    if (line.startsWith('Satellites:')) {
      _btGpsSatellites = int.tryParse(line.split(':').last.trim());
      _updateGpsFromBtScratch();
      return;
    }
    if (line.startsWith('HDOP:')) {
      _btGpsHdop = double.tryParse(line.split(':').last.trim());
      _updateGpsFromBtScratch();
      return;
    }

    if (line.startsWith('Command:')) {
      final cmd = line.split(':').last.trim();
      _status = _status.copyWith(
        command: cmd,
        direction: cmd,
        isMoving: cmd != 'stop' && cmd != 's',
        source: 'bluetooth',
      );
      notifyListeners();
      return;
    }
    if (line.startsWith('Direction:')) {
      final direction = line.split(':').last.trim();
      _status = _status.copyWith(
        direction: direction,
        isMoving: direction != 'none' && direction != 'stop' && direction != 's',
        source: 'bluetooth',
      );
      notifyListeners();
      return;
    }
    if (line.startsWith('Moving:')) {
      final moving = line.split(':').last.trim().toUpperCase();
      _status = _status.copyWith(
        isMoving: moving == 'YES' || moving == 'TRUE',
        source: 'bluetooth',
      );
      notifyListeners();
      return;
    }
    if (line.startsWith('Battery:')) {
      final raw = line.split(':').last.trim().replaceAll('%', '').trim();
      final battery = int.tryParse(raw);
      if (battery != null) {
        _status = _status.copyWith(battery: battery, source: 'bluetooth');
        notifyListeners();
      }
      return;
    }
  }

  void _updateGpsFromBtScratch() {
    final lat = _btGpsLatitude;
    final lon = _btGpsLongitude;
    if (lat == null || lon == null) return;

    _gpsData = GPSData(
      latitude: lat,
      longitude: lon,
      altitude: _btGpsAltitude ?? _gpsData.altitude,
      speed: _btGpsSpeedMps ?? _gpsData.speed,
      course: _btGpsCourse ?? _gpsData.course,
      satellites: _btGpsSatellites ?? _gpsData.satellites,
      hdop: _btGpsHdop ?? _gpsData.hdop,
      timestamp: DateTime.now(),
      isValid: _btGpsIsValid ?? _gpsData.isValid,
    );
    notifyListeners();
  }

  void sendBluetoothCommand(String command) {
    final conn = _bluetoothConnection;
    if (conn == null || !conn.isConnected) return;
    conn.output.add(utf8.encode('$command\n'));
  }

  void disconnect() {
    _bluetoothInputSub?.cancel();
    _bluetoothInputSub = null;

    try {
      _bluetoothConnection?.finish();
    } catch (_) {}
    _bluetoothConnection?.dispose();
    _bluetoothConnection = null;
    _bluetoothDevice = null;

    stopStatusPolling();
    stopGPSPolling();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _isConnected = false;
    _connectionType = ConnectionType.none;
    _isConnecting = false;
    _connectionMessage = 'Disconnected';

    _status = RoverStatus.disconnected;
    _info = null;
    _gpsData = GPSData.invalid;

    notifyListeners();
  }

  Future<void> fetchSystemInfo() async {
    if (_connectionType != ConnectionType.wifi) return;

    try {
      final response = await http
          .get(Uri.parse('http://$_wifiIP/api/info'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _info = RoverInfo.fromJson(data);
        notifyListeners();
      }
    } catch (_) {}
  }

  void startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_connectionType == ConnectionType.wifi && _isConnected) {
        unawaited(fetchStatus());
      }
    });
  }

  void stopStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> fetchStatus() async {
    if (_connectionType != ConnectionType.wifi) return;

    try {
      final response = await http
          .get(Uri.parse('http://$_wifiIP/api/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _status = RoverStatus.fromJson(data).copyWith(source: 'wifi');
        notifyListeners();
        return;
      }
    } catch (_) {}

    // If WiFi status fails, treat as disconnected and try to reconnect.
    if (_isConnected) {
      _isConnected = false;
      _connectionMessage = 'Disconnected';
      stopStatusPolling();
      stopGPSPolling();
      notifyListeners();
    }

    if (_reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (_connectionType == ConnectionType.wifi && !_isConnected && !_isConnecting) {
        unawaited(connectWiFi());
      }
    });
  }

  Future<void> sendCommand(RoverCommand command) async {
    if (!_isConnected) return;

    final cmdString = _getCommandString(command);

    if (_connectionType == ConnectionType.wifi) {
      await sendWiFiCommand(cmdString);
    } else if (_connectionType == ConnectionType.bluetooth) {
      sendBluetoothCommand(cmdString);
    }
  }

  Future<void> sendWiFiCommand(String command) async {
    try {
      await http
          .get(Uri.parse('http://$_wifiIP/$command'))
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  Future<void> setSpeed(int speed) async {
    if (!_isConnected) return;

    final clamped = speed.clamp(0, 255);
    _status = _status.copyWith(speed: clamped);
    notifyListeners();

    if (_connectionType == ConnectionType.wifi) {
      try {
        await http
            .get(Uri.parse('http://$_wifiIP/api/speed?value=$clamped'))
            .timeout(const Duration(seconds: 1));
      } catch (_) {}
    } else if (_connectionType == ConnectionType.bluetooth) {
      sendBluetoothCommand('speed$clamped');
    }
  }

  Future<void> emergencyStop() async {
    await sendCommand(RoverCommand.stop);
  }

  Future<void> fetchGPSData() async {
    if (!_isConnected) return;

    if (_connectionType == ConnectionType.wifi) {
      try {
        final response = await http
            .get(Uri.parse('http://$_wifiIP/api/gps/data'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('📡 GPS API Response: ${data['is_valid']} - Lat: ${data['latitude']}, Lon: ${data['longitude']}, Sats: ${data['satellites']}');
          _gpsData = GPSData.fromJson(data);
          notifyListeners();
        } else {
          print('❌ GPS API Error: Status ${response.statusCode}');
        }
      } catch (e) {
        print('❌ GPS Fetch Failed: $e');
        // GPS data fetch failed, keep previous data
      }
    } else if (_connectionType == ConnectionType.bluetooth) {
      // For Bluetooth, send GPS request command
      sendBluetoothCommand('gps');
    }
  }

  void startGPSPolling({Duration interval = const Duration(seconds: 3)}) {
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(interval, (_) {
      fetchGPSData();
    });
  }

  void stopGPSPolling() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  Future<bool> sampleSoil() async {
    if (!_isConnected) return false;

    if (_connectionType == ConnectionType.wifi) {
      try {
        final response = await http
            .get(Uri.parse('http://$_wifiIP/api/sample/soil'))
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          print('✓ Soil sampling started');
          return true;
        }
      } catch (e) {
        print('❌ Soil sampling failed: $e');
      }
    } else if (_connectionType == ConnectionType.bluetooth) {
      sendBluetoothCommand('sample');
      return true;
    }
    
    return false;
  }

  String _getCommandString(RoverCommand command) {
    switch (command) {
      case RoverCommand.forward:
        return 'f';
      case RoverCommand.backward:
        return 'b';
      case RoverCommand.left:
        return 'l';
      case RoverCommand.right:
        return 'r';
      case RoverCommand.rotateLeft:
        return 'rl';
      case RoverCommand.rotateRight:
        return 'rr';
      case RoverCommand.stop:
        return 's';
    }
  }

  String getCommandDisplay(RoverCommand command) {
    switch (command) {
      case RoverCommand.forward:
        return 'Forward';
      case RoverCommand.backward:
        return 'Backward';
      case RoverCommand.left:
        return 'Left';
      case RoverCommand.right:
        return 'Right';
      case RoverCommand.rotateLeft:
        return 'Rotate Left';
      case RoverCommand.rotateRight:
        return 'Rotate Right';
      case RoverCommand.stop:
        return 'Stop';
    }
  }

  @override
  void dispose() {
    stopStatusPolling();
    stopGPSPolling();
    _reconnectTimer?.cancel();
    _bluetoothConnection?.dispose();
    super.dispose();
  }
}
