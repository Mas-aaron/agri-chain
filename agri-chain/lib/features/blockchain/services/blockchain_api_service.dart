import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/blockchain_config.dart';
import '../models/yield_asset.dart';

/// Service for communicating with blockchain backend API
class BlockchainApiService {
  final http.Client _httpClient;

  BlockchainApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Get all yield assets for a farmer
  Future<List<YieldAsset>> getYieldAssets(String farmerId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${BlockchainConfig.apiBaseUrl}/assets?farmerId=$farmerId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(BlockchainConfig.apiTimeout);

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
      final response = await _httpClient.get(
        Uri.parse('${BlockchainConfig.apiBaseUrl}/assets/$assetId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
    try {
      final response = await _httpClient
          .post(
            Uri.parse('${BlockchainConfig.apiBaseUrl}/assets'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(asset.toJson()),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return YieldAsset.fromJson(jsonDecode(response.body));
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing yield asset
  Future<YieldAsset> updateYieldAsset(String assetId, YieldAsset asset) async {
    try {
      final response = await _httpClient
          .put(
            Uri.parse('${BlockchainConfig.apiBaseUrl}/assets/$assetId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(asset.toJson()),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (response.statusCode == 200) {
        return YieldAsset.fromJson(jsonDecode(response.body));
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a yield asset
  Future<void> deleteYieldAsset(String assetId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('${BlockchainConfig.apiBaseUrl}/assets/$assetId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(BlockchainConfig.apiTimeout);

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw _handleError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get yield portfolio summary for a farmer
  Future<Map<String, dynamic>> getPortfolioSummary(String farmerId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${BlockchainConfig.apiBaseUrl}/portfolio/$farmerId/summary'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(BlockchainConfig.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Execute a token trade
  Future<Map<String, dynamic>> executeTrade(
    String assetId,
    double amount,
    String tradeType,
  ) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('${BlockchainConfig.apiBaseUrl}/trades'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'assetId': assetId,
              'amount': amount,
              'tradeType': tradeType, // 'BUY' or 'SELL'
            }),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get market data for a crop type
  Future<Map<String, dynamic>> getMarketData(String cropType) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${BlockchainConfig.apiBaseUrl}/market/crop/$cropType'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(BlockchainConfig.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Handle HTTP errors
  Exception _handleError(http.Response response) {
    try {
      final error = jsonDecode(response.body);
      final message = error['message'] ?? 'Unknown error';
      return Exception('API Error (${response.statusCode}): $message');
    } catch (_) {
      return Exception(
        'API Error (${response.statusCode}): ${response.reasonPhrase}',
      );
    }
  }
}
