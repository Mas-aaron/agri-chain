/// Flutter ChangeNotifier provider for the Logistics Aggregation feature.
///
/// Manages transport request and job state for the UI, following the same
/// pattern as [BlockchainProvider]:
/// - Exposes loading/error state
/// - Delegates all API calls to [LogisticsApiService]
/// - Calls [notifyListeners] after every state mutation
///
/// Requirements: 11.3, 11.5, 11.6, 12.2, 12.5, 13.5

import 'package:flutter/foundation.dart';

import '../models/logistics_models.dart';
import '../services/logistics_api_service.dart';

/// Provider that manages the state for the logistics aggregation feature.
///
/// Screens consume this provider via `Provider.of<LogisticsProvider>(context)`
/// or `context.watch<LogisticsProvider>()`.
class LogisticsProvider extends ChangeNotifier {
  final LogisticsApiService _service;

  LogisticsProvider({LogisticsApiService? service})
      : _service = service ?? LogisticsApiService();

  // ── State ─────────────────────────────────────────────────────────────────

  /// The farmer's most recently submitted (or loaded) transport request.
  TransportRequest? _currentRequest;

  /// The list of aggregated jobs loaded from the job board.
  List<AggregatedJob> _jobs = [];

  /// Whether an async operation is in progress.
  bool _isLoading = false;

  /// Human-readable error message from the last failed operation, or `null`.
  String? _errorMessage;

  // ── Getters ───────────────────────────────────────────────────────────────

  TransportRequest? get currentRequest => _currentRequest;
  List<AggregatedJob> get jobs => List.unmodifiable(_jobs);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Exposes the underlying [LogisticsApiService] for direct use in screens
  /// that need fine-grained control (e.g. passing filters not covered by
  /// provider methods).
  LogisticsApiService get service => _service;

  // ── Farmer: transport request operations ─────────────────────────────────

  /// Submits a new farmer transport request.
  ///
  /// On success, updates [currentRequest] with the returned record.
  /// On failure, sets [errorMessage] and leaves [currentRequest] unchanged.
  ///
  /// Requirements: 11.3
  Future<void> submitRequest({
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = await _service.submitTransportRequest(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pickupParish: pickupParish,
        pickupSubcounty: pickupSubcounty,
        destinationMarket: destinationMarket,
        cropType: cropType,
        quantityKg: quantityKg,
        harvestReadyAt: harvestReadyAt,
        farmerNotes: farmerNotes,
      );
      _currentRequest = request;
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads a single transport request by ID and updates [currentRequest].
  ///
  /// Requirements: 11.5
  Future<void> loadCurrentRequest(String requestId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = await _service.getRequest(requestId: requestId);
      _currentRequest = request;
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancels the [currentRequest] and clears it from state.
  ///
  /// Does nothing if [currentRequest] is null.
  ///
  /// Requirements: 11.6
  Future<void> cancelCurrentRequest() async {
    final request = _currentRequest;
    if (request == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.cancelRequest(requestId: request.id);
      _currentRequest = null;
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Logistics company: job board operations ───────────────────────────────

  /// Loads aggregated jobs from the job board, optionally filtered.
  ///
  /// Replaces the current [jobs] list with the result.
  ///
  /// Requirements: 12.2, 12.5
  Future<void> loadJobs({
    String? status,
    String? market,
    double? minQuantityKg,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.listJobs(
        status: status,
        market: market,
        minQuantityKg: minQuantityKg,
      );
      _jobs = result;
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Accepts an aggregated job on behalf of a logistics company.
  ///
  /// On success, replaces the matching entry in [jobs] with the updated job
  /// returned by the API. If the job is not currently in [jobs], it is
  /// appended to the list.
  ///
  /// Requirements: 13.5
  Future<void> acceptJob(
    String jobId, {
    required String companyId,
    required double truckCapacityKg,
    required String driverPhone,
    DateTime? plannedPickupAt,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedJob = await _service.acceptJob(
        jobId: jobId,
        companyId: companyId,
        truckCapacityKg: truckCapacityKg,
        driverPhone: driverPhone,
        plannedPickupAt: plannedPickupAt,
      );

      // Refresh the job in the list.
      final index = _jobs.indexWhere((j) => j.id == jobId);
      if (index >= 0) {
        _jobs = List<AggregatedJob>.from(_jobs)..[index] = updatedJob;
      } else {
        _jobs = [..._jobs, updatedJob];
      }
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Clears [errorMessage] and notifies listeners.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Converts an exception into a human-readable string for [errorMessage].
  String _parseError(Object error) {
    if (error is LogisticsApiException) {
      return error.message;
    }
    final msg = error.toString();
    // Network / connectivity errors
    if (msg.contains('TimeoutException') ||
        msg.contains('Future not completed') ||
        msg.contains('timed out')) {
      return 'Could not reach the server. The logistics backend may not be running yet.\n\nPlease ensure the Go server is started and try again.';
    }
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Network is unreachable')) {
      return 'No connection to the server. Please check that the backend is running and your device is connected.';
    }
    if (error is Exception) {
      return msg.replaceFirst('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }
}
