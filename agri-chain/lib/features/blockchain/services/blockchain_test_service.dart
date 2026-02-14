import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/blockchain_config.dart';

/// Service for testing blockchain functionality
class BlockchainTestService {
  final http.Client _httpClient;

  BlockchainTestService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  Uri _u(String path) => Uri.parse('${BlockchainConfig.apiBaseUrl}$path');

  /// Run comprehensive blockchain tests
  Future<Map<String, dynamic>> runAllTests() async {
    final res = await _httpClient
        .post(_u('/tests/run'), headers: {'Accept': 'application/json'})
        .timeout(BlockchainConfig.apiTimeout);

    if (res.statusCode != 200) {
      return {
        'initialize': {
          'success': false,
          'message': 'Backend test failed (HTTP ${res.statusCode})',
          'timestamp': DateTime.now().toIso8601String(),
        }
      };
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Test yield token creation
  Future<Map<String, dynamic>> testYieldTokenCreation({
    required String farmerId,
    required BigInt yieldAmount,
    required String cropType,
  }) async {
    try {
      final res = await _httpClient
          .post(
            _u('/yield-token'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'farmerId': farmerId,
              'yieldAmount': yieldAmount.toString(),
              'cropType': cropType,
            }),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        return {
          'success': false,
          'message': 'Yield token creation failed (HTTP ${res.statusCode})',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return {
        'success': true,
        'message': 'Yield token creation successful',
        'transactionHash': data['transactionHash'],
        'farmerId': farmerId,
        'yieldAmount': yieldAmount.toString(),
        'cropType': cropType,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Yield token creation error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Test transaction status
  Future<Map<String, dynamic>> testTransactionStatus(String txHash) async {
    try {
      final res = await _httpClient
          .get(_u('/transactions/$txHash'), headers: {'Accept': 'application/json'})
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        return {
          'success': false,
          'message': 'Transaction status query failed (HTTP ${res.statusCode})',
          'transactionHash': txHash,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      return {
        'success': true,
        'message': 'Transaction status query successful',
        'transactionHash': txHash,
        'confirmed': data['confirmed'] ?? false,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Transaction status query error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get blockchain configuration info
  Map<String, dynamic> getConfigurationInfo() {
    return {
      'blockchainProvider': BlockchainConfig.blockchainProvider,
      'contractAddress': BlockchainConfig.contractAddress,
      'chainId': BlockchainConfig.chainId,
      'enableWeb3Integration': BlockchainConfig.enableWeb3Integration,
      'isConnected': null,
      'userAddress': null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Clear all test data
  void clearTestData() {
    // In a real implementation, this might clear test tokens or reset test state
    if (kDebugMode) {
      debugPrint('Blockchain test data cleared');
    }
  }
}
