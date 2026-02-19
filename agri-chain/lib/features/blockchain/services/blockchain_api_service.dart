import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/blockchain_config.dart';
import '../models/yield_asset.dart';

/// Service for communicating with blockchain backend API
class BlockchainApiService {
  final http.Client _httpClient;

  BlockchainApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

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

  /// Get all yield assets for a farmer
  Future<List<YieldAsset>> getYieldAssets(String farmerId) async {
    try {
      final idToken = await _idToken();
      final response = await _httpClient
          .get(
            Uri.parse('${BlockchainConfig.apiBaseUrl}/v1/yield-assets'),
            headers: _headers(idToken: idToken),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .cast<Map<String, dynamic>>()
            .map((asset) => YieldAsset.fromJson(asset))
            .toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get a single yield asset by ID
  Future<YieldAsset> getYieldAsset(String assetId) async {
    try {
      final idToken = await _idToken();
      final response = await _httpClient.get(
        Uri.parse('${BlockchainConfig.apiBaseUrl}/v1/yield-assets/$assetId'),
        headers: _headers(idToken: idToken),
      ).timeout(BlockchainConfig.apiTimeout);

      if (response.statusCode == 200) {
        return YieldAsset.fromJson(jsonDecode(response.body));
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new yield asset
  Future<YieldAsset> createYieldAsset(YieldAsset asset) async {
    throw Exception('Use mintYieldAssetFromPrediction() in Fabric/BCS mode');
  }

  Future<Map<String, dynamic>> mintYieldAssetFromPrediction({
    required String cropType,
    String? insuranceTier,
    required String region,
    required String soilType,
    required double rainfallMm,
    required double temperatureCelsius,
    required bool fertilizerUsed,
    required bool irrigationUsed,
    required String weatherCondition,
    required int daysToHarvest,
  }) async {
    final idToken = await _idToken();
    final response = await _httpClient
        .post(
          Uri.parse('${BlockchainConfig.apiBaseUrl}/v1/yield-assets/mint'),
          headers: _headers(idToken: idToken),
          body: jsonEncode({
            'cropType': cropType,
            if (insuranceTier != null && insuranceTier.trim().isNotEmpty) 'insuranceTier': insuranceTier.trim(),
            'region': region,
            'soil_type': soilType,
            'rainfall_mm': rainfallMm,
            'temperature_celsius': temperatureCelsius,
            'fertilizer_used': fertilizerUsed,
            'irrigation_used': irrigationUsed,
            'weather_condition': weatherCondition,
            'days_to_harvest': daysToHarvest,
          }),
        )
        .timeout(BlockchainConfig.apiTimeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      throw Exception('Invalid mint response');
    }

    throw _handleError(response);
  }

  /// Update an existing yield asset
  Future<YieldAsset> updateYieldAsset(String assetId, YieldAsset asset) async {
    throw Exception('Not supported in Fabric/BCS mode');
  }

  /// Delete a yield asset
  Future<void> deleteYieldAsset(String assetId) async {
    throw Exception('Not supported in Fabric/BCS mode');
  }

  /// Get yield portfolio summary for a farmer
  Future<Map<String, dynamic>> getPortfolioSummary(String farmerId) async {
    return {
      'farmerId': farmerId,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Execute a token trade
  Future<Map<String, dynamic>> executeTrade(
    String assetId,
    double amount,
    String tradeType,
  ) async {
    throw Exception('Not supported in Fabric/BCS mode');
  }

  /// Get market data for a crop type
  Future<Map<String, dynamic>> getMarketData(String cropType) async {
    throw Exception('Not supported in Fabric/BCS mode');
  }

  /// Handle HTTP errors
  Exception _handleError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        // Go gateway errors: {"error": {"code": "...", "message": "...", "details": {...}}}
        final err = decoded['error'];
        if (err is Map) {
          final code = err['code'];
          final msg = err['message'];
          final codeStr = code == null ? '' : ' $code';
          final msgStr = msg == null ? 'Unknown error' : '$msg';
          return Exception('API Error (${response.statusCode})$codeStr: $msgStr');
        }

        // Legacy errors: {"message": "..."}
        final message = decoded['message'] ?? decoded['detail'] ?? 'Unknown error';
        return Exception('API Error (${response.statusCode}): $message');
      }

      return Exception('API Error (${response.statusCode}): ${response.reasonPhrase}');
    } catch (_) {
      return Exception(
        'API Error (${response.statusCode}): ${response.reasonPhrase}',
      );
    }
  }
}
