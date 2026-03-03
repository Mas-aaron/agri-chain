// HTTP service for all /verifier/* backend endpoints.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agri_chain/config/app_config.dart';

class VerifierApiService {
  String get _base => '${AppConfig.apiBaseUrl}/verifier';

  // ── Registration ──────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String userId,
    required String organizationName,
    String organizationType = 'INSPECTOR',
  }) async {
    final res = await http.post(
      Uri.parse('$_base/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'organization_name': organizationName,
        'organization_type': organizationType,
      }),
    );
    return _decode(res);
  }

  // ── Dashboard ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboard(int verifierId) async {
    final res = await http.get(
      Uri.parse('$_base/dashboard?verifier_id=$verifierId'),
    );
    return _decode(res);
  }

  // ── Pending assets ────────────────────────────────────────────

  Future<Map<String, dynamic>> getPendingAssets() async {
    final res = await http.get(Uri.parse('$_base/pending-assets'));
    return _decode(res);
  }

  // ── Submit report ─────────────────────────────────────────────

  Future<Map<String, dynamic>> submitReport({
    required int verifierId,
    required String assetId,
    required double submittedYield,
    double confidence = 0.8,
    String dataSource = 'INSPECTOR',
    String measurementMethod = '',
    String notes = '',
  }) async {
    final res = await http.post(
      Uri.parse('$_base/submit-report'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'verifier_id': verifierId,
        'asset_id': assetId,
        'submitted_yield': submittedYield,
        'confidence': confidence,
        'data_source': dataSource,
        'measurement_method': measurementMethod,
        'notes': notes,
      }),
    );
    return _decode(res);
  }

  // ── Submissions ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getMySubmissions(int verifierId, {int limit = 50}) async {
    final res = await http.get(
      Uri.parse('$_base/my-submissions?verifier_id=$verifierId&limit=$limit'),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> getSubmissionDetail(int submissionId) async {
    final res = await http.get(Uri.parse('$_base/submission/$submissionId'));
    return _decode(res);
  }

  // ── Consensus ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getConsensusReports({int limit = 50}) async {
    final res = await http.get(
      Uri.parse('$_base/consensus-reports?limit=$limit'),
    );
    return _decode(res);
  }

  // ── Staking ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> stakeTokens({
    required int verifierId,
    required double amount,
    int lockDays = 30,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/stake'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'verifier_id': verifierId,
        'amount': amount,
        'lock_days': lockDays,
      }),
    );
    return _decode(res);
  }

  // ── Rewards ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRewards(int verifierId, {int limit = 50}) async {
    final res = await http.get(
      Uri.parse('$_base/rewards?verifier_id=$verifierId&limit=$limit'),
    );
    return _decode(res);
  }

  // ── Profile ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile(int verifierId) async {
    final res = await http.get(
      Uri.parse('$_base/profile?verifier_id=$verifierId'),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateProfile(int verifierId, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$_base/profile?verifier_id=$verifierId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _decode(res);
  }

  // ── Health ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> health() async {
    final res = await http.get(Uri.parse('$_base/health'));
    return _decode(res);
  }

  // ── Helper ────────────────────────────────────────────────────

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }
}
