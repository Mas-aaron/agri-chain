import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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

  RoverStatus _status = RoverStatus.disconnected;
  RoverInfo? _info;

  bool _isConnected = false;
  bool _isConnecting = false;
  String _connectionMessage = 'Disconnected';

  Timer? _statusTimer;
  Timer? _reconnectTimer;

  SharedPreferences? _prefs;

  ConnectionType get connectionType => _connectionType;
  String get wifiIP => _wifiIP;
  BluetoothDevice? get bluetoothDevice => _bluetoothDevice;
  RoverStatus get status => _status;
  RoverInfo? get info => _info;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get connectionMessage => _connectionMessage;

  RoverProvider() {
    unawaited(loadPreferences());
  }

  Future<void> loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _wifiIP = _prefs!.getString('rover_wifi_ip') ?? '192.168.4.1';
    notifyListeners();
  }

  Future<void> savePreferences() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString('rover_wifi_ip', _wifiIP);
  }

  void setWifiIP(String ip) {
    _wifiIP = ip.trim();
    unawaited(savePreferences());
    notifyListeners();
  }

  Future<bool> connectWiFi() async {
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
        // Some devices require BLUETOOTH_SCAN even for listing bonded devices.
        await Permission.bluetoothScan.request();
      }

      await FlutterBluetoothSerial.instance.requestEnable();
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  Future<bool> connectBluetooth(BluetoothDevice device) async {
    _connectionType = ConnectionType.bluetooth;
    _bluetoothDevice = device;
    _isConnecting = true;
    _connectionMessage = 'Connecting via Bluetooth...';
    notifyListeners();

    try {
      _bluetoothConnection = await BluetoothConnection.toAddress(device.address);

      _isConnected = true;
      _connectionMessage = 'Connected via Bluetooth';

      _bluetoothConnection!.input!.listen((data) {
        final response = utf8.decode(data, allowMalformed: true);
        processBluetoothResponse(response);
      });

      sendBluetoothCommand('status');

      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isConnected = false;
      _connectionMessage = 'Bluetooth connection failed';
      _connectionType = ConnectionType.none;
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  void processBluetoothResponse(String response) {
    final trimmed = response.trim();
    if (!trimmed.startsWith('STATUS:')) return;

    try {
      final parts = trimmed.split(':');
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
  }

  void sendBluetoothCommand(String command) {
    final conn = _bluetoothConnection;
    if (conn == null || !conn.isConnected) return;
    conn.output.add(utf8.encode('$command\n'));
  }

  void disconnect() {
    _bluetoothConnection?.dispose();
    _bluetoothConnection = null;

    stopStatusPolling();

    _isConnected = false;
    _connectionType = ConnectionType.none;
    _connectionMessage = 'Disconnected';

    _status = RoverStatus.disconnected;
    _info = null;

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
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
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
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _status = RoverStatus.fromJson(data).copyWith(source: 'wifi');
        notifyListeners();
        return;
      }
    } catch (_) {}

    if (_reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (_isConnected) {
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
    _reconnectTimer?.cancel();
    _bluetoothConnection?.dispose();
    super.dispose();
  }
}
