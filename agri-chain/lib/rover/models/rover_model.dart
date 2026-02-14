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
