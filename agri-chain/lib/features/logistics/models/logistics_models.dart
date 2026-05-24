/// Dart models for the Logistics Aggregation feature.
///
/// These models correspond to the Go backend types in
/// `internal/logistics/types.go` and are used by [LogisticsApiService]
/// and the logistics UI screens.

// ---------------------------------------------------------------------------
// TransportRequest
// ---------------------------------------------------------------------------

/// A farmer's request to transport produce from a pickup location to a
/// destination market.
///
/// Status values: PENDING | AGGREGATED | ASSIGNED | COMPLETED | CANCELLED
class TransportRequest {
  final String id;
  final String farmerUid;
  final String farmerName;
  final double pickupLat;
  final double pickupLng;
  final String pickupParish;
  final String destinationMarket;
  final String cropType;
  final double quantityKg;

  /// One of: PENDING, AGGREGATED, ASSIGNED, COMPLETED, CANCELLED
  final String status;

  /// Nullable — set once the request is aggregated into a job.
  final String? jobId;

  final DateTime createdAt;

  const TransportRequest({
    required this.id,
    required this.farmerUid,
    required this.farmerName,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupParish,
    required this.destinationMarket,
    required this.cropType,
    required this.quantityKg,
    required this.status,
    this.jobId,
    required this.createdAt,
  });

  factory TransportRequest.fromJson(Map<String, dynamic> json) {
    return TransportRequest(
      id: json['id'] as String? ?? '',
      farmerUid: json['farmer_uid'] as String? ?? '',
      farmerName: json['farmer_name'] as String? ?? '',
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0.0,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? 0.0,
      pickupParish: json['pickup_parish'] as String? ?? '',
      destinationMarket: json['destination_market'] as String? ?? '',
      cropType: json['crop_type'] as String? ?? '',
      quantityKg: (json['quantity_kg'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'PENDING',
      jobId: json['job_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farmer_uid': farmerUid,
      'farmer_name': farmerName,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup_parish': pickupParish,
      'destination_market': destinationMarket,
      'crop_type': cropType,
      'quantity_kg': quantityKg,
      'status': status,
      'job_id': jobId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Returns a copy of this [TransportRequest] with the given fields replaced.
  TransportRequest copyWith({
    String? id,
    String? farmerUid,
    String? farmerName,
    double? pickupLat,
    double? pickupLng,
    String? pickupParish,
    String? destinationMarket,
    String? cropType,
    double? quantityKg,
    String? status,
    Object? jobId = _sentinel,
    DateTime? createdAt,
  }) {
    return TransportRequest(
      id: id ?? this.id,
      farmerUid: farmerUid ?? this.farmerUid,
      farmerName: farmerName ?? this.farmerName,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      pickupParish: pickupParish ?? this.pickupParish,
      destinationMarket: destinationMarket ?? this.destinationMarket,
      cropType: cropType ?? this.cropType,
      quantityKg: quantityKg ?? this.quantityKg,
      status: status ?? this.status,
      jobId: jobId == _sentinel ? this.jobId : jobId as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransportRequest &&
        other.id == id &&
        other.farmerUid == farmerUid &&
        other.farmerName == farmerName &&
        other.pickupLat == pickupLat &&
        other.pickupLng == pickupLng &&
        other.pickupParish == pickupParish &&
        other.destinationMarket == destinationMarket &&
        other.cropType == cropType &&
        other.quantityKg == quantityKg &&
        other.status == status &&
        other.jobId == jobId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        farmerUid,
        farmerName,
        pickupLat,
        pickupLng,
        pickupParish,
        destinationMarket,
        cropType,
        quantityKg,
        status,
        jobId,
        createdAt,
      );

  @override
  String toString() =>
      'TransportRequest(id: $id, status: $status, farmerUid: $farmerUid, '
      'destination: $destinationMarket, quantityKg: $quantityKg)';
}

// ---------------------------------------------------------------------------
// AggregatedJob
// ---------------------------------------------------------------------------

/// A transport job created by the aggregation engine, grouping multiple
/// farmer requests along a shared corridor.
///
/// Status values: OPEN | ASSIGNED | IN_TRANSIT | COMPLETED | CANCELLED
class AggregatedJob {
  final String id;
  final String destinationMarket;
  final String originRegion;
  final double totalQuantityKg;
  final int farmerCount;

  /// One of: OPEN, ASSIGNED, IN_TRANSIT, COMPLETED, CANCELLED
  final String status;

  /// Nullable — populated once the route optimizer has run.
  final RouteResult? route;

  /// Nullable geographic centroid of the pickup cluster.
  final double? centroidLat;
  final double? centroidLng;

  final DateTime createdAt;

  const AggregatedJob({
    required this.id,
    required this.destinationMarket,
    required this.originRegion,
    required this.totalQuantityKg,
    required this.farmerCount,
    required this.status,
    this.route,
    this.centroidLat,
    this.centroidLng,
    required this.createdAt,
  });

  factory AggregatedJob.fromJson(Map<String, dynamic> json) {
    return AggregatedJob(
      id: json['id'] as String? ?? '',
      destinationMarket: json['destination_market'] as String? ?? '',
      originRegion: json['origin_region'] as String? ?? '',
      totalQuantityKg: (json['total_quantity_kg'] as num?)?.toDouble() ?? 0.0,
      farmerCount: json['farmer_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'OPEN',
      route: json['route'] != null
          ? RouteResult.fromJson(json['route'] as Map<String, dynamic>)
          : null,
      centroidLat: (json['centroid_lat'] as num?)?.toDouble(),
      centroidLng: (json['centroid_lng'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination_market': destinationMarket,
      'origin_region': originRegion,
      'total_quantity_kg': totalQuantityKg,
      'farmer_count': farmerCount,
      'status': status,
      'route': route?.toJson(),
      'centroid_lat': centroidLat,
      'centroid_lng': centroidLng,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Returns a copy of this [AggregatedJob] with the given fields replaced.
  AggregatedJob copyWith({
    String? id,
    String? destinationMarket,
    String? originRegion,
    double? totalQuantityKg,
    int? farmerCount,
    String? status,
    Object? route = _sentinel,
    Object? centroidLat = _sentinel,
    Object? centroidLng = _sentinel,
    DateTime? createdAt,
  }) {
    return AggregatedJob(
      id: id ?? this.id,
      destinationMarket: destinationMarket ?? this.destinationMarket,
      originRegion: originRegion ?? this.originRegion,
      totalQuantityKg: totalQuantityKg ?? this.totalQuantityKg,
      farmerCount: farmerCount ?? this.farmerCount,
      status: status ?? this.status,
      route: route == _sentinel ? this.route : route as RouteResult?,
      centroidLat:
          centroidLat == _sentinel ? this.centroidLat : centroidLat as double?,
      centroidLng:
          centroidLng == _sentinel ? this.centroidLng : centroidLng as double?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AggregatedJob &&
        other.id == id &&
        other.destinationMarket == destinationMarket &&
        other.originRegion == originRegion &&
        other.totalQuantityKg == totalQuantityKg &&
        other.farmerCount == farmerCount &&
        other.status == status &&
        other.route == route &&
        other.centroidLat == centroidLat &&
        other.centroidLng == centroidLng &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        destinationMarket,
        originRegion,
        totalQuantityKg,
        farmerCount,
        status,
        route,
        centroidLat,
        centroidLng,
        createdAt,
      );

  @override
  String toString() =>
      'AggregatedJob(id: $id, status: $status, destination: $destinationMarket, '
      'farmers: $farmerCount, totalKg: $totalQuantityKg)';
}

// ---------------------------------------------------------------------------
// RouteResult
// ---------------------------------------------------------------------------

/// The optimised pickup route for an [AggregatedJob], produced by the
/// nearest-neighbour route optimizer.
class RouteResult {
  final List<RouteStop> orderedStops;
  final double totalDistanceKm;
  final double estimatedHours;

  const RouteResult({
    required this.orderedStops,
    required this.totalDistanceKm,
    required this.estimatedHours,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final stopsJson = json['ordered_stops'] as List<dynamic>? ?? [];
    return RouteResult(
      orderedStops: stopsJson
          .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
          .toList(),
      totalDistanceKm:
          (json['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ordered_stops': orderedStops.map((s) => s.toJson()).toList(),
      'total_distance_km': totalDistanceKm,
      'estimated_hours': estimatedHours,
    };
  }

  /// Returns a copy of this [RouteResult] with the given fields replaced.
  RouteResult copyWith({
    List<RouteStop>? orderedStops,
    double? totalDistanceKm,
    double? estimatedHours,
  }) {
    return RouteResult(
      orderedStops: orderedStops ?? this.orderedStops,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      estimatedHours: estimatedHours ?? this.estimatedHours,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RouteResult) return false;
    if (other.totalDistanceKm != totalDistanceKm) return false;
    if (other.estimatedHours != estimatedHours) return false;
    if (other.orderedStops.length != orderedStops.length) return false;
    for (var i = 0; i < orderedStops.length; i++) {
      if (other.orderedStops[i] != orderedStops[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(orderedStops), totalDistanceKm, estimatedHours);

  @override
  String toString() =>
      'RouteResult(stops: ${orderedStops.length}, '
      'totalDistanceKm: $totalDistanceKm, estimatedHours: $estimatedHours)';
}

// ---------------------------------------------------------------------------
// RouteStop
// ---------------------------------------------------------------------------

/// A single pickup stop within a [RouteResult].
class RouteStop {
  /// 1-based sequential stop index.
  final int stopOrder;
  final String requestId;
  final String farmerName;
  final String parish;
  final double lat;
  final double lng;
  final double quantityKg;

  const RouteStop({
    required this.stopOrder,
    required this.requestId,
    required this.farmerName,
    required this.parish,
    required this.lat,
    required this.lng,
    required this.quantityKg,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      stopOrder: json['stop_order'] as int? ?? 0,
      requestId: json['request_id'] as String? ?? '',
      farmerName: json['farmer_name'] as String? ?? '',
      parish: json['parish'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      quantityKg: (json['quantity_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stop_order': stopOrder,
      'request_id': requestId,
      'farmer_name': farmerName,
      'parish': parish,
      'lat': lat,
      'lng': lng,
      'quantity_kg': quantityKg,
    };
  }

  /// Returns a copy of this [RouteStop] with the given fields replaced.
  RouteStop copyWith({
    int? stopOrder,
    String? requestId,
    String? farmerName,
    String? parish,
    double? lat,
    double? lng,
    double? quantityKg,
  }) {
    return RouteStop(
      stopOrder: stopOrder ?? this.stopOrder,
      requestId: requestId ?? this.requestId,
      farmerName: farmerName ?? this.farmerName,
      parish: parish ?? this.parish,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      quantityKg: quantityKg ?? this.quantityKg,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteStop &&
        other.stopOrder == stopOrder &&
        other.requestId == requestId &&
        other.farmerName == farmerName &&
        other.parish == parish &&
        other.lat == lat &&
        other.lng == lng &&
        other.quantityKg == quantityKg;
  }

  @override
  int get hashCode => Object.hash(
        stopOrder,
        requestId,
        farmerName,
        parish,
        lat,
        lng,
        quantityKg,
      );

  @override
  String toString() =>
      'RouteStop(order: $stopOrder, farmer: $farmerName, parish: $parish, '
      'lat: $lat, lng: $lng, quantityKg: $quantityKg)';
}

// ---------------------------------------------------------------------------
// Internal sentinel for nullable copyWith parameters
// ---------------------------------------------------------------------------

/// Private sentinel object used by [copyWith] methods to distinguish between
/// "caller passed null explicitly" and "caller did not pass the argument".
const Object _sentinel = Object();
