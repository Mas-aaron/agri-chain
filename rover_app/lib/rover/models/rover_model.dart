enum ConnectionType { wifi, bluetooth, none }

enum RoverCommand {
  forward,
  backward,
  left,
  right,
  rotateLeft,
  rotateRight,
  stop,
}

class GPSData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed; // in m/s
  final double course; // heading direction
  final int satellites;
  final double hdop; // horizontal dilution of precision
  final DateTime timestamp;
  final bool isValid;

  const GPSData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.course,
    required this.satellites,
    required this.hdop,
    required this.timestamp,
    required this.isValid,
  });

  factory GPSData.fromJson(Map<String, dynamic> json) {
    return GPSData(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      course: (json['course'] as num?)?.toDouble() ?? 0.0,
      satellites: json['satellites'] as int? ?? 0,
      hdop: (json['hdop'] as num?)?.toDouble() ?? 99.99,
      timestamp: DateTime.now(), // Use current time since ESP32 doesn't have RTC
      isValid: json['is_valid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'course': course,
      'satellites': satellites,
      'hdop': hdop,
      'timestamp': timestamp.toIso8601String(),
      'is_valid': isValid,
    };
  }

  static final DateTime invalid_timestamp = DateTime.utc(1970, 1, 1);

  static final GPSData invalid = GPSData(
    latitude: 0.0,
    longitude: 0.0,
    altitude: 0.0,
    speed: 0.0,
    course: 0.0,
    satellites: 0,
    hdop: 99.99,
    timestamp: DateTime.utc(1970, 1, 1),
    isValid: false,
  );

  String get coordinatesString => '$latitude, $longitude';

  String get speedKmh => '${(speed * 3.6).toStringAsFixed(2)} km/h';

  String get courseString {
    if (course < 0 || course > 360) return 'N/A';
    if (course < 22.5 || course >= 337.5) return 'N';
    if (course < 67.5) return 'NE';
    if (course < 112.5) return 'E';
    if (course < 157.5) return 'SE';
    if (course < 202.5) return 'S';
    if (course < 247.5) return 'SW';
    if (course < 292.5) return 'W';
    return 'NW';
  }
}

class RoverStatus {
  final String command;
  final String direction;
  final bool isMoving;
  final int speed;
  final int battery;
  final int uptime;
  final int clients;
  final String source;

  const RoverStatus({
    required this.command,
    required this.direction,
    required this.isMoving,
    required this.speed,
    required this.battery,
    required this.uptime,
    required this.clients,
    required this.source,
  });

  RoverStatus copyWith({
    String? command,
    String? direction,
    bool? isMoving,
    int? speed,
    int? battery,
    int? uptime,
    int? clients,
    String? source,
  }) {
    return RoverStatus(
      command: command ?? this.command,
      direction: direction ?? this.direction,
      isMoving: isMoving ?? this.isMoving,
      speed: speed ?? this.speed,
      battery: battery ?? this.battery,
      uptime: uptime ?? this.uptime,
      clients: clients ?? this.clients,
      source: source ?? this.source,
    );
  }

  factory RoverStatus.fromJson(Map<String, dynamic> json) {
    return RoverStatus(
      command: json['command'] ?? 'stop',
      direction: json['direction'] ?? 'none',
      isMoving: json['isMoving'] ?? false,
      speed: json['speed'] ?? 255,
      battery: json['battery'] ?? 100,
      uptime: json['uptime'] ?? 0,
      clients: json['clients'] ?? 0,
      source: json['source'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'command': command,
      'direction': direction,
      'isMoving': isMoving,
      'speed': speed,
      'battery': battery,
      'uptime': uptime,
      'clients': clients,
      'source': source,
    };
  }

  static const RoverStatus disconnected = RoverStatus(
    command: 'stop',
    direction: 'none',
    isMoving: false,
    speed: 255,
    battery: 100,
    uptime: 0,
    clients: 0,
    source: 'none',
  );
}

class RoverInfo {
  final String name;
  final String version;
  final String board;
  final String driver;
  final String wifiSSID;
  final String wifiIP;
  final String bluetooth;
  final List<String> features;
  final List<String> endpoints;

  const RoverInfo({
    required this.name,
    required this.version,
    required this.board,
    required this.driver,
    required this.wifiSSID,
    required this.wifiIP,
    required this.bluetooth,
    required this.features,
    required this.endpoints,
  });

  factory RoverInfo.fromJson(Map<String, dynamic> json) {
    return RoverInfo(
      name: json['name'] ?? 'ESP32 Rover',
      version: json['version'] ?? '1.0.0',
      board: json['board'] ?? 'ESP32',
      driver: json['driver'] ?? 'D0-D3',
      wifiSSID: json['wifi_ssid'] ?? 'ESP32_Rover',
      wifiIP: json['wifi_ip'] ?? '192.168.4.1',
      bluetooth: json['bluetooth'] ?? 'ESP32_Rover_BT',
      features: List<String>.from(json['features'] ?? const []),
      endpoints: List<String>.from(json['endpoints'] ?? const []),
    );
  }
}
