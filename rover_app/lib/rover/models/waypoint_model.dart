import 'dart:math';

class Waypoint {
  final int index;
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;

  const Waypoint({
    required this.index,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
  });

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      index: json['index'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  String get coordinatesString => '$latitude, $longitude';
}

class Route {
  final String name;
  final List<Waypoint> waypoints;
  final DateTime createdAt;

  const Route({
    required this.name,
    required this.waypoints,
    required this.createdAt,
  });

  int get waypointCount => waypoints.length;

  double getTotalDistance() {
    if (waypoints.isEmpty) return 0.0;

    double total = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += _calculateDistance(
        waypoints[i].latitude,
        waypoints[i].longitude,
        waypoints[i + 1].latitude,
        waypoints[i + 1].longitude,
      );
    }
    return total;
  }

  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000.0; // Earth radius in meters
    final double dLat = (lat2 - lat1) * 3.14159 / 180.0;
    final double dLon = (lon2 - lon1) * 3.14159 / 180.0;

    final double a = (sin(dLat / 2.0) * sin(dLat / 2.0)) +
        (cos(lat1 * 3.14159 / 180.0) *
            cos(lat2 * 3.14159 / 180.0) *
            sin(dLon / 2.0) *
            sin(dLon / 2.0));

    final double c = 2.0 * (atan2(sqrt(a), sqrt(1.0 - a)));
    return R * c;
  }
}

class NavigationStatus {
  final bool isNavigating;
  final int currentWaypoint;
  final int totalWaypoints;
  final String routeName;
  final double? targetLatitude;
  final double? targetLongitude;
  final double? distanceToTarget;
  final bool? targetReached;
  final double? bearing;

  const NavigationStatus({
    required this.isNavigating,
    required this.currentWaypoint,
    required this.totalWaypoints,
    required this.routeName,
    this.targetLatitude,
    this.targetLongitude,
    this.distanceToTarget,
    this.targetReached,
    this.bearing,
  });

  factory NavigationStatus.fromJson(Map<String, dynamic> json) {
    final navigatingValue = json['navigating'] ?? json['isNavigating'];

    return NavigationStatus(
      isNavigating: navigatingValue as bool? ?? false,
      currentWaypoint: json['currentWaypoint'] as int? ?? 0,
      totalWaypoints: json['totalWaypoints'] as int? ?? 0,
      routeName: json['routeName'] as String? ?? 'Unknown',
      targetLatitude:
          ((json['targetLat'] ?? json['targetLatitude']) as num?)?.toDouble(),
      targetLongitude:
          ((json['targetLon'] ?? json['targetLongitude']) as num?)?.toDouble(),
      distanceToTarget: (json['distanceToTarget'] as num?)?.toDouble(),
      targetReached: json['targetReached'] as bool?,
      bearing: (json['bearing'] as num?)?.toDouble(),
    );
  }

  double get progressPercentage => totalWaypoints > 0
      ? ((currentWaypoint) / totalWaypoints) * 100
      : 0.0;
}
