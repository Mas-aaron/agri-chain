// ChangeNotifier provider for the verifier subsystem.
// Manages state for dashboard stats, pending assets, submissions, etc.

import 'package:flutter/material.dart';
import 'package:agri_chain/services/verifier_api_service.dart';
import 'package:agri_chain/models/verifier_models.dart';

class VerifierProvider extends ChangeNotifier {
  final VerifierApiService _api = VerifierApiService();

  // ── State ──────────────────────────────────────────────────────

  bool isLoading = false;
  String? error;

  Verifier? verifier;
  Map<String, dynamic> dashboardStats = {};
  List<Map<String, dynamic>> pendingAssets = [];
  List<OracleSubmission> recentSubmissions = [];
  List<ConsensusReport> recentReports = [];
  List<VerifierReward> rewards = [];
  double totalRewards = 0.0;

  // ── Convenience getters for screens ───────────────────────────
  List<Map<String, dynamic>> get submissionHistory =>
      recentSubmissions.map((s) => {
            'asset_id': s.assetId,
            'submitted_yield': s.submittedYield,
            'confidence': s.confidence,
            'status': s.status,
            'data_source': s.dataSource,
          }).toList();

  Map<String, dynamic> get profile => verifier != null
      ? {
          'organization_name': verifier!.organizationName,
          'organization_type': verifier!.organizationType,
        }
      : {};

  // ── Registration ──────────────────────────────────────────────

  Future<void> register({
    required String userId,
    required String organizationName,
    String organizationType = 'INSPECTOR',
  }) async {
    _setLoading(true);
    try {
      final res = await _api.register(
        userId: userId,
        organizationName: organizationName,
        organizationType: organizationType,
      );
      final raw = res['verifier'] as Map<String, dynamic>;
      verifier = Verifier.fromJson(raw);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
  }

  // ── Dashboard ─────────────────────────────────────────────────

  Future<void> loadDashboardData() async {
    if (verifier == null) return;
    _setLoading(true);
    try {
      final dashRes = await _api.getDashboard(verifier!.id);
      dashboardStats = dashRes['dashboard'] as Map<String, dynamic>? ?? {};

      final assetsRes = await _api.getPendingAssets();
      pendingAssets = List<Map<String, dynamic>>.from(assetsRes['assets'] ?? []);

      final subsRes = await _api.getMySubmissions(verifier!.id, limit: 5);
      final rawSubs = subsRes['submissions'] as List? ?? [];
      recentSubmissions =
          rawSubs.map((s) => OracleSubmission.fromJson(s)).toList();

      final reportsRes = await _api.getConsensusReports(limit: 5);
      final rawReports = reportsRes['reports'] as List? ?? [];
      recentReports =
          rawReports.map((r) => ConsensusReport.fromJson(r)).toList();

      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
  }

  // ── Submit report ─────────────────────────────────────────────

  Future<Map<String, dynamic>> submitReport({
    required String assetId,
    double? submittedYield,
    double? yieldValue,
    double confidence = 0.8,
    String dataSource = 'INSPECTOR',
    String measurementMethod = '',
    String notes = '',
  }) async {
    if (verifier == null) throw Exception('Not registered');
    final res = await _api.submitReport(
      verifierId: verifier!.id,
      assetId: assetId,
      submittedYield: yieldValue ?? submittedYield ?? 0.0,
      confidence: confidence,
      dataSource: dataSource,
      measurementMethod: measurementMethod,
      notes: notes,
    );
    // Refresh dashboard after submission
    await loadDashboardData();
    return res;
  }

  // ── Submissions ───────────────────────────────────────────────

  Future<void> loadSubmissionHistory({int limit = 50}) async {
    if (verifier == null) return;
    _setLoading(true);
    try {
      final subs = await loadAllSubmissions(limit: limit);
      recentSubmissions = subs;
      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> loadPendingAssets() async {
    if (verifier == null) return;
    _setLoading(true);
    try {
      final res = await _api.getPendingAssets();
      pendingAssets = List<Map<String, dynamic>>.from(res['assets'] ?? []);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
  }

  Future<List<OracleSubmission>> loadAllSubmissions({int limit = 50}) async {
    if (verifier == null) return [];
    final res = await _api.getMySubmissions(verifier!.id, limit: limit);
    final rawSubs = res['submissions'] as List? ?? [];
    return rawSubs.map((s) => OracleSubmission.fromJson(s)).toList();
  }

  // ── Staking ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> stakeTokens(double amount, [int? lockDaysPos, int lockDays = 30]) async {
    if (verifier == null) throw Exception('Not registered');
    final res = await _api.stakeTokens(
      verifierId: verifier!.id,
      amount: amount,
      lockDays: lockDaysPos ?? lockDays,
    );
    // Refresh profile
    await _refreshProfile();
    return res;
  }

  // ── Rewards ───────────────────────────────────────────────────

  Future<void> loadRewards() async {
    if (verifier == null) return;
    try {
      final res = await _api.getRewards(verifier!.id);
      final rawRewards = res['rewards'] as List? ?? [];
      rewards = rawRewards.map((r) => VerifierReward.fromJson(r)).toList();
      totalRewards = (res['total'] as num?)?.toDouble() ?? 0.0;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  // ── Profile ───────────────────────────────────────────────────

  Future<void> loadProfile([int? verifierId]) async {
    final id = verifierId ?? verifier?.id;
    if (id == null) return;
    _setLoading(true);
    try {
      final res = await _api.getProfile(id);
      verifier = Verifier.fromJson(res['profile'] as Map<String, dynamic>);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (verifier == null) return;
    _setLoading(true);
    try {
      final res = await _api.updateProfile(verifier!.id, data);
      verifier = Verifier.fromJson(res['profile'] as Map<String, dynamic>);
      error = null;
    } catch (e) {
      error = e.toString();
    }
    _setLoading(false);
  }

  // ── Helpers ───────────────────────────────────────────────────

  Future<void> _refreshProfile() async {
    if (verifier == null) return;
    try {
      final res = await _api.getProfile(verifier!.id);
      verifier = Verifier.fromJson(res['profile'] as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {}
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
