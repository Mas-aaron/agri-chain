class BackendSensorPoint {
  final String? id;
  final String deviceId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final String? sessionId;
  final String? farmId;
  final DateTime? createdAt;

  const BackendSensorPoint({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    this.sessionId,
    this.farmId,
    required this.createdAt,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    return null;
  }

  factory BackendSensorPoint.fromJson(Map<String, dynamic> json) {
    return BackendSensorPoint(
      id: (json['id'] ?? json['_id'])?.toString(),
      deviceId: (json['device_id'] ?? json['deviceId'] ?? json['device'])
              ?.toString() ??
          'unknown',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble(),
      sessionId: (json['session_id'] ?? json['sessionId'])?.toString(),
      farmId: (json['farm_id'] ?? json['farmId'])?.toString(),
      createdAt: _parseDateTime(
        json['created_at'] ??
            json['createdAt'] ??
            json['timestamp'] ??
            json['time'],
      ),
    );
  }

  bool get isValidLatLon {
    if (latitude.isNaN || longitude.isNaN) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude == 0.0 && longitude == 0.0) return false;
    return true;
  }
}
