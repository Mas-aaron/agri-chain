import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rover_app/rover/models/waypoint_model.dart' as waypoint_model;
import '../models/rover_model.dart';
import 'rover_provider.dart';

class PathRecordingProvider extends ChangeNotifier {
  final RoverProvider roverProvider;
  String _wifiIP = '192.168.4.1';
  String? _lastError;
  bool _isFetchingRecordingData = false;

  // Recording state
  bool _isRecording = false;
  List<waypoint_model.Waypoint> _recordedWaypoints = [];
  Timer? _recordingStatusTimer;

  // Navigation state
  waypoint_model.NavigationStatus _navigationStatus =
      waypoint_model.NavigationStatus(
    isNavigating: false,
    currentWaypoint: 0,
    totalWaypoints: 0,
    routeName: 'None',
  );
  Timer? _navigationStatusTimer;

  // Routes
  waypoint_model.Route? _activeRoute;
  List<waypoint_model.Route> _savedRoutes = [];

  // Getters
  bool get isRecording => _isRecording;
  List<waypoint_model.Waypoint> get recordedWaypoints => _recordedWaypoints;
  int get waypointCount => _recordedWaypoints.length;
  waypoint_model.NavigationStatus get navigationStatus => _navigationStatus;
  waypoint_model.Route? get activeRoute => _activeRoute;
  List<waypoint_model.Route> get savedRoutes => _savedRoutes;
  String? get lastError => _lastError;

  PathRecordingProvider(this.roverProvider) {
    _wifiIP = roverProvider.wifiIP;
  }

  // ===== RECORDING =====
  Future<bool> startRecording() async {
    _lastError = null;
    _wifiIP = roverProvider.wifiIP;

    if (!roverProvider.isConnected) {
      _lastError = 'Not connected to rover';
      return false;
    }

    if (roverProvider.connectionType != ConnectionType.wifi) {
      _lastError = 'Recording requires WiFi connection';
      return false;
    }

    try {
      final response = await http
          .get(Uri.parse('http://$_wifiIP/api/recording/start'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _isRecording = true;
        _recordedWaypoints = [];
        _startRecordingStatusTimer();
        notifyListeners();
        return true;
      }

      // If the rover is already recording, we can treat it as active recording
      // and start polling instead of hard-failing.
      if (response.statusCode == 400) {
        try {
          final data = json.decode(response.body);
          final message = (data is Map<String, dynamic>)
              ? (data['message'] as String?)
              : null;
          if (message == 'Recording already in progress') {
            _isRecording = true;
            _startRecordingStatusTimer();
            notifyListeners();
            return true;
          }
        } catch (_) {}
      }

      try {
        final data = json.decode(response.body);
        _lastError = (data is Map<String, dynamic>)
            ? (data['message'] as String?)
            : null;
      } catch (_) {
        _lastError = null;
      }
      _lastError ??= 'Server error (${response.statusCode})';
    } catch (e) {
      _lastError = e.toString();
    }

    return false;
  }

  Future<bool> stopRecording() async {
    _lastError = null;
    _wifiIP = roverProvider.wifiIP;

    if (!_isRecording) {
      _lastError = 'No recording in progress';
      return false;
    }

    try {
      final response = await http
          .get(Uri.parse('http://$_wifiIP/api/recording/stop'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _isRecording = false;
        _recordingStatusTimer?.cancel();
        notifyListeners();
        return true;
      }
      try {
        final data = json.decode(response.body);
        _lastError = (data is Map<String, dynamic>)
            ? (data['message'] as String?)
            : null;
      } catch (_) {
        _lastError = null;
      }
      _lastError ??= 'Server error (${response.statusCode})';
    } catch (e) {
      _lastError = e.toString();
    }

    return false;
  }

  void _startRecordingStatusTimer() {
    _recordingStatusTimer?.cancel();
    _recordingStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchRecordingData();
    });
  }

  Future<void> _fetchRecordingData() async {
    if (!_isRecording) return;

    if (!roverProvider.isConnected || roverProvider.connectionType != ConnectionType.wifi) {
      _isRecording = false;
      _recordingStatusTimer?.cancel();
      _recordingStatusTimer = null;
      _lastError = 'Disconnected from rover';
      notifyListeners();
      return;
    }

    if (_isFetchingRecordingData) return;
    _isFetchingRecordingData = true;

    _wifiIP = roverProvider.wifiIP;

    try {
      final response = await http
          .get(Uri.parse('http://$_wifiIP/api/recording/data'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final waypointsList =
            (data['waypoints'] as List?)
                ?.map(
                  (w) => waypoint_model.Waypoint.fromJson(
                    w as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            [];

        _recordedWaypoints = waypointsList;
        _lastError = null;
        notifyListeners();
        return;
      }
      _lastError = 'Server error (${response.statusCode})';
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    } finally {
      _isFetchingRecordingData = false;
    }
  }

  Future<bool> saveRoute(String routeName) async {
    _lastError = null;
    _wifiIP = roverProvider.wifiIP;

    if (_recordedWaypoints.isEmpty) return false;

    try {
      final response = await http
          .post(
            Uri.parse('http://$_wifiIP/api/recording/save?name=$routeName'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = waypoint_model.Route(
          name: data['name'] as String? ?? routeName,
          waypoints: _recordedWaypoints,
          createdAt: DateTime.now(),
        );

        _activeRoute = route;
        _savedRoutes.add(route);
        _recordedWaypoints = [];
        _lastError = null;

        notifyListeners();
        return true;
      }
      try {
        final data = json.decode(response.body);
        _lastError = (data is Map<String, dynamic>)
            ? (data['message'] as String?)
            : null;
      } catch (_) {
        _lastError = null;
      }
      _lastError ??= 'Server error (${response.statusCode})';
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }

    return false;
  }

  // ===== NAVIGATION =====
  Future<bool> startNavigation() async {
    if (!roverProvider.isConnected || _activeRoute == null) return false;

    try {
      final response = await http
          .get(Uri.parse('http://$_wifiIP/api/navigation/start'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        _startNavigationStatusTimer();
        notifyListeners();
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<bool> stopNavigation() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_wifiIP/api/navigation/stop'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        _navigationStatusTimer?.cancel();
        _navigationStatus = waypoint_model.NavigationStatus(
          isNavigating: false,
          currentWaypoint: 0,
          totalWaypoints: 0,
          routeName: 'None',
        );
        notifyListeners();
        return true;
      }
    } catch (_) {}

    return false;
  }

  void _startNavigationStatusTimer() {
    _navigationStatusTimer?.cancel();
    _navigationStatusTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) {
      _fetchNavigationStatus();
    });
  }

  Future<void> _fetchNavigationStatus() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_wifiIP/api/navigation/status'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _navigationStatus = waypoint_model.NavigationStatus.fromJson(
          data as Map<String, dynamic>,
        );

        // Stop timer if navigation complete
        if (!_navigationStatus.isNavigating) {
          _navigationStatusTimer?.cancel();
        }

        notifyListeners();
      }
    } catch (_) {}
  }

  void loadRoute(waypoint_model.Route route) {
    _activeRoute = route;
    notifyListeners();
  }

  @override
  void dispose() {
    _recordingStatusTimer?.cancel();
    _navigationStatusTimer?.cancel();
    super.dispose();
  }
}
