/// HTTP client for all `/v1/logistics/*` backend endpoints.
///
/// Follows the same pattern as [BlockchainApiService]:
/// - Firebase ID token passed as `Authorization: Bearer <token>`
/// - Base URL from [AppConfig.apiBaseUrl]
/// - Error responses parsed from `{"error": {"code": "...", "message": "..."}}` envelope
/// - Typed [LogisticsApiException] thrown for known error codes

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:agri_chain/config/app_config.dart';
import '../models/logistics_models.dart';

// ---------------------------------------------------------------------------
// Typed exceptions
// ---------------------------------------------------------------------------

/// Base class for all logistics API errors.
class LogisticsApiException implements Exception {
  /// Machine-readable error code from the backend (e.g. `CAPACITY_INSUFFICIENT`).
  final String code;

  /// Human-readable message from the backend.
  final String message;

  /// HTTP status code of the response.
  final int statusCode;

  /// Optional structured details from the `details` field of the error envelope.
  final Map<String, dynamic>? details;

  const LogisticsApiException({
    required this.code,
    required this.message,
    required this.statusCode,
    this.details,
  });

  @override
  String toString() =>
      'LogisticsApiException($statusCode, $code): $message';
}

/// Thrown when a logistics company attempts to accept a job with a truck
/// capacity smaller than the job's total quantity.
///
/// Corresponds to backend error code `CAPACITY_INSUFFICIENT` (HTTP 400).
class CapacityInsufficientException extends LogisticsApiException {
  const CapacityInsufficientException({
    required super.message,
    required super.statusCode,
    super.details,
  }) : super(code: 'CAPACITY_INSUFFICIENT');
}

/// Thrown when a job has already been accepted by another logistics company.
///
/// Corresponds to backend error code `JOB_ALREADY_ASSIGNED` (HTTP 409).
class JobAlreadyAssignedException extends LogisticsApiException {
  const JobAlreadyAssignedException({
    required super.message,
    required super.statusCode,
    super.details,
  }) : super(code: 'JOB_ALREADY_ASSIGNED');
}

/// Thrown when submitted pickup coordinates fall outside Uganda's bounding box.
///
/// Corresponds to backend error code `OUTSIDE_UGANDA_BOUNDS` (HTTP 400).
class OutsideUgandaBoundsException extends LogisticsApiException {
  const OutsideUgandaBoundsException({
    required super.message,
    required super.statusCode,
    super.details,
  }) : super(code: 'OUTSIDE_UGANDA_BOUNDS');
}

/// Thrown when a farmer attempts to cancel a request that is in `ASSIGNED`
/// or later status.
///
/// Corresponds to backend error code `REQUEST_NOT_CANCELLABLE` (HTTP 400).
class RequestNotCancellableException extends LogisticsApiException {
  const RequestNotCancellableException({
    required super.message,
    required super.statusCode,
    super.details,
  }) : super(code: 'REQUEST_NOT_CANCELLABLE');
}

// ---------------------------------------------------------------------------
// LogisticsApiService
// ---------------------------------------------------------------------------

/// HTTP client wrapping all `/v1/logistics/*` API calls.
///
/// Usage:
/// ```dart
/// final service = LogisticsApiService();
/// final request = await service.submitTransportRequest(
///   pickupLat: 0.347596,
///   pickupLng: 32.582520,
///   pickupParish: 'Nakawa',
///   destinationMarket: 'Kampala - St. Balikuddembe',
///   cropType: 'Maize',
///   quantityKg: 500.0,
/// );
/// ```
class LogisticsApiService {
  final http.Client _httpClient;

  /// Timeout for all API calls. Mobile networks in Uganda can be slow.
  static const Duration _timeout = Duration(seconds: 20);

  LogisticsApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  // ── Auth helpers ──────────────────────────────────────────────────────────

  /// Returns the current Firebase ID token, or `null` if not signed in.
  Future<String?> _idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  Map<String, String> _headers({String? idToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (idToken != null && idToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $idToken';
    }
    return headers;
  }

  // ── URL helpers ───────────────────────────────────────────────────────────

  String get _base => '${AppConfig.apiBaseUrl}/v1/logistics';

  Uri _uri(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$_base$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  // ── Error parsing ─────────────────────────────────────────────────────────

  /// Parses the `{"error": {"code": "...", "message": "...", "details": {...}}}`
  /// envelope and throws the appropriate typed exception.
  ///
  /// Falls back to a generic [LogisticsApiException] for unknown codes.
  Never _throwFromResponse(http.Response resp) {
    String code = 'UNKNOWN_ERROR';
    String message = 'An unexpected error occurred (${resp.statusCode})';
    Map<String, dynamic>? details;

    try {
      final body = jsonDecode(resp.body);
      if (body is Map) {
        final err = body['error'];
        if (err is Map) {
          code = (err['code'] as String?) ?? code;
          message = (err['message'] as String?) ?? message;
          final rawDetails = err['details'];
          if (rawDetails is Map) {
            details = rawDetails.cast<String, dynamic>();
          }
        } else {
          // Fallback: plain {"message": "..."} or {"detail": "..."}
          message = (body['message'] ?? body['detail'] ?? message).toString();
        }
      }
    } catch (_) {
      // Body is not valid JSON — keep defaults
    }

    switch (code) {
      case 'CAPACITY_INSUFFICIENT':
        throw CapacityInsufficientException(
          message: message,
          statusCode: resp.statusCode,
          details: details,
        );
      case 'JOB_ALREADY_ASSIGNED':
        throw JobAlreadyAssignedException(
          message: message,
          statusCode: resp.statusCode,
          details: details,
        );
      case 'OUTSIDE_UGANDA_BOUNDS':
        throw OutsideUgandaBoundsException(
          message: message,
          statusCode: resp.statusCode,
          details: details,
        );
      case 'REQUEST_NOT_CANCELLABLE':
        throw RequestNotCancellableException(
          message: message,
          statusCode: resp.statusCode,
          details: details,
        );
      default:
        throw LogisticsApiException(
          code: code,
          message: message,
          statusCode: resp.statusCode,
          details: details,
        );
    }
  }

  // ── Transport Request endpoints ───────────────────────────────────────────

  /// Submits a new farmer transport request.
  ///
  /// **POST** `/v1/logistics/requests`
  ///
  /// Throws [OutsideUgandaBoundsException] if the pickup coordinates are
  /// outside Uganda's bounding box, or a generic [LogisticsApiException] for
  /// other validation errors.
  ///
  /// Requirements: 11.3, 16.1, 16.5
  Future<TransportRequest> submitTransportRequest({
    required double pickupLat,
    required double pickupLng,
    required String pickupParish,
    String? pickupSubcounty,
    required String destinationMarket,
    required String cropType,
    required double quantityKg,
    DateTime? harvestReadyAt,
    String? farmerNotes,
  }) async {
    final idToken = await _idToken();

    final body = <String, dynamic>{
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup_parish': pickupParish,
      'destination_market': destinationMarket,
      'crop_type': cropType,
      'quantity_kg': quantityKg,
    };
    if (pickupSubcounty != null) body['pickup_subcounty'] = pickupSubcounty;
    if (harvestReadyAt != null) {
      body['harvest_ready_at'] = harvestReadyAt.toUtc().toIso8601String();
    }
    if (farmerNotes != null) body['farmer_notes'] = farmerNotes;

    final resp = await _httpClient
        .post(
          _uri('/requests'),
          headers: _headers(idToken: idToken),
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        throw LogisticsApiException(
          code: 'INVALID_RESPONSE',
          message: 'Expected a JSON object in submitTransportRequest response',
          statusCode: resp.statusCode,
        );
      }
      return TransportRequest.fromJson(decoded.cast<String, dynamic>());
    }

    _throwFromResponse(resp);
  }

  /// Retrieves a single transport request by ID.
  ///
  /// **GET** `/v1/logistics/requests/:id`
  ///
  /// Throws [LogisticsApiException] with HTTP 403 if the request belongs to
  /// a different farmer.
  ///
  /// Requirements: 11.3
  Future<TransportRequest> getRequest({required String requestId}) async {
    final idToken = await _idToken();

    final resp = await _httpClient
        .get(
          _uri('/requests/$requestId'),
          headers: _headers(idToken: idToken),
        )
        .timeout(_timeout);

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        throw LogisticsApiException(
          code: 'INVALID_RESPONSE',
          message: 'Expected a JSON object in getRequest response',
          statusCode: resp.statusCode,
        );
      }
      return TransportRequest.fromJson(decoded.cast<String, dynamic>());
    }

    _throwFromResponse(resp);
  }

  /// Cancels a transport request.
  ///
  /// **DELETE** `/v1/logistics/requests/:id`
  ///
  /// Only requests in `PENDING` or `AGGREGATED` status can be cancelled.
  /// Throws [RequestNotCancellableException] if the request is in `ASSIGNED`
  /// or later status.
  ///
  /// Requirements: 11.3, 16.4
  Future<void> cancelRequest({required String requestId}) async {
    final idToken = await _idToken();

    final resp = await _httpClient
        .delete(
          _uri('/requests/$requestId'),
          headers: _headers(idToken: idToken),
        )
        .timeout(_timeout);

    if (resp.statusCode == 200 || resp.statusCode == 204) {
      return;
    }

    _throwFromResponse(resp);
  }

  // ── Job Board endpoints ───────────────────────────────────────────────────

  /// Returns a paginated list of aggregated jobs, optionally filtered.
  ///
  /// **GET** `/v1/logistics/jobs`
  ///
  /// Parameters:
  /// - [status] — filter by job status (e.g. `OPEN`, `ASSIGNED`)
  /// - [market] — filter by destination market
  /// - [minQuantityKg] — filter to jobs with `total_quantity_kg ≥ minQuantityKg`
  /// - [limit] — page size (default 20, backend max 100)
  /// - [offset] — pagination offset (default 0)
  ///
  /// Requirements: 12.2, 13.5
  Future<List<AggregatedJob>> listJobs({
    String? status,
    String? market,
    double? minQuantityKg,
    int limit = 20,
    int offset = 0,
  }) async {
    final idToken = await _idToken();

    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (market != null && market.trim().isNotEmpty) {
      query['market'] = market.trim();
    }
    if (minQuantityKg != null) {
      query['min_kg'] = '$minQuantityKg';
    }

    final resp = await _httpClient
        .get(
          _uri('/jobs', query: query),
          headers: _headers(idToken: idToken),
        )
        .timeout(_timeout);

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      // Backend may return a list directly or wrap it: {"jobs": [...]}
      final List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map) {
        final jobs = decoded['jobs'];
        if (jobs is List) {
          list = jobs;
        } else {
          throw LogisticsApiException(
            code: 'INVALID_RESPONSE',
            message: 'Expected a JSON array or {"jobs": [...]} in listJobs response',
            statusCode: resp.statusCode,
          );
        }
      } else {
        throw LogisticsApiException(
          code: 'INVALID_RESPONSE',
          message: 'Unexpected response shape in listJobs',
          statusCode: resp.statusCode,
        );
      }

      return list
          .whereType<Map>()
          .map((e) => AggregatedJob.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
    }

    _throwFromResponse(resp);
  }

  /// Accepts an aggregated job on behalf of a logistics company.
  ///
  /// **POST** `/v1/logistics/jobs/:id/accept`
  ///
  /// Throws [CapacityInsufficientException] if `truckCapacityKg` is less than
  /// the job's `total_quantity_kg`.
  ///
  /// Throws [JobAlreadyAssignedException] if the job was accepted concurrently
  /// by another company (HTTP 409).
  ///
  /// Requirements: 16.2, 16.3
  Future<AggregatedJob> acceptJob({
    required String jobId,
    required String companyId,
    required double truckCapacityKg,
    required String driverPhone,
    DateTime? plannedPickupAt,
  }) async {
    final idToken = await _idToken();

    final body = <String, dynamic>{
      'company_id': companyId,
      'truck_capacity_kg': truckCapacityKg,
      'driver_phone': driverPhone,
    };
    if (plannedPickupAt != null) {
      body['planned_pickup_at'] = plannedPickupAt.toUtc().toIso8601String();
    }

    final resp = await _httpClient
        .post(
          _uri('/jobs/$jobId/accept'),
          headers: _headers(idToken: idToken),
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        throw LogisticsApiException(
          code: 'INVALID_RESPONSE',
          message: 'Expected a JSON object in acceptJob response',
          statusCode: resp.statusCode,
        );
      }
      return AggregatedJob.fromJson(decoded.cast<String, dynamic>());
    }

    _throwFromResponse(resp);
  }
}
