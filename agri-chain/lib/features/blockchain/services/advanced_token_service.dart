import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/blockchain_config.dart';
import 'web3_service.dart';

/// Token phases for transfer restrictions
enum TokenPhase {
  predicted, // Phase 1: Pre-harvest (free trading)
  harvesting, // Phase 2: During harvest (restricted trading)
  settled, // Phase 3: Post-harvest (physical delivery/settlement)
}

/// Insurance tiers
enum InsuranceTier {
  bronze, // 50% coverage, 3% premium
  silver, // 60% coverage, 2.5% premium
  gold, // 70% coverage, 2% premium
  platinum, // 80% coverage, 1.5% premium
}

/// Advanced token service implementing sophisticated transferability and risk management
class AdvancedTokenService {
  final Web3Service _web3Service;
  final http.Client _httpClient;

  AdvancedTokenService({Web3Service? web3Service, http.Client? httpClient})
      : _web3Service = web3Service ?? Web3Service(),
        _httpClient = httpClient ?? http.Client();

  Uri _u(String path) => Uri.parse('${BlockchainConfig.apiBaseUrl}$path');

  /// Create transferable yield token with phase-based restrictions
  Future<Map<String, dynamic>> createTransferableYieldToken({
    required String farmerId,
    required String cropType,
    required double predictedYield,
    required DateTime harvestDate,
    InsuranceTier insuranceTier = InsuranceTier.silver,
  }) async {
    try {
      if (!_web3Service.isConnected) {
        throw Exception('Wallet not connected');
      }

      final res = await _httpClient
          .post(
            _u('/advanced/tokenize'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'farmerId': farmerId,
              'cropType': cropType,
              'predictedYield': predictedYield,
              'harvestDate': harvestDate.toIso8601String(),
              'insuranceTier': insuranceTier.name,
            }),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Advanced tokenization failed');
      }

      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create transferable yield token',
      };
    }
  }

  /// Transfer tokens with phase-based validation
  Future<Map<String, dynamic>> transferTokens({
    required BigInt tokenId,
    required String toAddress,
    required double amount,
    Map<String, dynamic>? transferMetadata,
  }) async {
    try {
      if (!_web3Service.isConnected) {
        throw Exception('Wallet not connected');
      }

      final res = await _httpClient
          .post(
            _u('/advanced/transfer'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'tokenId': tokenId.toString(),
              'toAddress': toAddress,
              'amount': amount,
            }),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Transfer failed');
      }

      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Token transfer failed',
      };
    }
  }

  /// NOTE: Validation and phase rules are enforced server-side in Fabric implementation.

  /// Validate transfers in predicted phase (free trading with restrictions)
  Future<Map<String, dynamic>> _validatePredictedPhaseTransfer({
    required String fromAddress,
    required String toAddress,
    required double amount,
    required double predictedYield,
  }) async {
    // Check KYC requirements for large transfers
    if (amount > 10000) {
      final isKycVerified = await _checkKYCStatus(toAddress);
      if (!isKycVerified) {
        return {
          'isValid': false,
          'error': 'KYC required for transfers over 10,000 tokens',
          'currentPhase': TokenPhase.predicted.name,
        };
      }
    }

    // Check position limits
    final currentHoldings = await _getTokenHoldings(toAddress);
    if (currentHoldings + amount > 100000) {
      return {
        'isValid': false,
        'error': 'Exceeds maximum position limit of 100,000 tokens',
        'currentPhase': TokenPhase.predicted.name,
      };
    }

    // Check daily transfer limits
    final todayVolume = await _getDailyTransferVolume(toAddress);
    if (todayVolume + amount > 50000) {
      return {
        'isValid': false,
        'error': 'Exceeds daily transfer limit of 50,000 tokens',
        'currentPhase': TokenPhase.predicted.name,
      };
    }

    return {
      'isValid': true,
      'currentPhase': TokenPhase.predicted.name,
    };
  }

  /// Validate transfers in harvesting phase (restricted)
  Future<Map<String, dynamic>> _validateHarvestingPhaseTransfer({
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    // Check if recipient is authorized for harvest phase
    final isAuthorized = await _checkHarvestPhaseAuthorization(toAddress);
    if (!isAuthorized) {
      return {
        'isValid': false,
        'error': 'Transfers restricted during harvest phase to authorized participants only',
        'currentPhase': TokenPhase.harvesting.name,
      };
    }

    return {
      'isValid': true,
      'currentPhase': TokenPhase.harvesting.name,
    };
  }

  /// Validate transfers in settled phase (physical delivery)
  Future<Map<String, dynamic>> _validateSettledPhaseTransfer({
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    // Check if recipient has delivery capacity
    final hasDeliveryCapacity = await _checkDeliveryCapacity(toAddress);
    if (!hasDeliveryCapacity) {
      return {
        'isValid': false,
        'error': 'Recipient must have delivery capacity for settled tokens',
        'currentPhase': TokenPhase.settled.name,
      };
    }

    return {
      'isValid': true,
      'currentPhase': TokenPhase.settled.name,
    };
  }

  /// Create insurance policy for yield discrepancy protection
  Future<Map<String, dynamic>> createInsurancePolicy({
    required BigInt tokenId,
    required String farmerId,
    required double predictedYield,
    required InsuranceTier tier,
  }) async {
    try {
      final res = await _httpClient
          .post(
            _u('/insurance/policy'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'tokenId': tokenId.toString(),
              'farmerId': farmerId,
              'predictedYield': predictedYield,
              'tier': tier.name,
            }),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Failed to create insurance policy');
      }

      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create insurance policy',
      };
    }
  }

  /// Process actual yield and handle discrepancies
  Future<Map<String, dynamic>> processActualYield({
    required BigInt tokenId,
    required double actualYield,
    List<String>? oracleSourceIds,
  }) async {
    try {
      final res = await _httpClient
          .post(
            _u('/yield/process'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'tokenId': tokenId.toString(),
              'actualYield': actualYield,
            }),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Failed to process actual yield');
      }

      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to process actual yield',
      };
    }
  }

  /// Submit yield data to multi-oracle consensus system
  Future<Map<String, dynamic>> _submitYieldToOracle({
    required BigInt tokenId,
    required double actualYield,
    required List<String> sourceIds,
  }) async {
    try {
      // Simulate multi-oracle consensus
      final yields = <double>[];
      final weights = <double>[
        0.35, // government
        0.25, // university
        0.25, // satellite
        0.15, // local inspector
      ];

      for (int i = 0; i < sourceIds.length && i < weights.length; i++) {
        // In real implementation, query actual oracles
        // For now, simulate with some variance
        final variance = (DateTime.now().millisecondsSinceEpoch % 1000 - 500) / 10000;
        yields.add(actualYield * (1 + variance));
      }

      // Calculate weighted median
      final consensusYield = _calculateWeightedMedian(yields, weights);
      final confidence = _calculateConsensusConfidence(yields, consensusYield);

      return {
        'consensusYield': consensusYield,
        'confidence': confidence,
        'sourceCount': yields.length,
        'isVerified': confidence >= 0.7,
        'individualYields': yields,
      };
    } catch (e) {
      return {
        'isVerified': false,
        'error': e.toString(),
        'confidence': 0.0,
      };
    }
  }

  /// Trigger insurance claim for major discrepancies
  Future<Map<String, dynamic>?> _triggerInsuranceClaim(BigInt tokenId, double discrepancy) async {
    try {
      final res = await _httpClient
          .post(
            _u('/insurance/claim'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'tokenId': tokenId.toString(),
              'discrepancy': discrepancy,
              'policyId': null,
            }),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        return null;
      }

      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get comprehensive token information
  Future<Map<String, dynamic>> getTokenInfo(BigInt tokenId) async {
    try {
      final res = await _httpClient
          .get(_u('/token-info/${tokenId.toString()}'), headers: {'Accept': 'application/json'})
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Token info query failed');
      }

      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get transfer eligibility for a token
  Future<Map<String, dynamic>> getTransferEligibility(BigInt tokenId) async {
    try {
      final tokenInfo = await getTokenInfo(tokenId);
      final currentPhase = TokenPhase.values.firstWhere(
        (phase) => phase.name == tokenInfo['currentPhase'],
        orElse: () => TokenPhase.predicted,
      );

      Map<String, dynamic> restrictions = {};
      
      switch (currentPhase) {
        case TokenPhase.predicted:
          restrictions = {
            'maxTransferAmount': 10000.0,
            'dailyTransferLimit': 50000.0,
            'positionLimit': 100000.0,
            'kycRequired': true,
            'description': 'Free trading with KYC requirements for large transfers',
          };
          break;
          
        case TokenPhase.harvesting:
          restrictions = {
            'authorizedParticipants': ['original_farmer', 'licensed_processors', 'delivery_warehouses'],
            'description': 'Restricted trading to authorized participants only',
          };
          break;
          
        case TokenPhase.settled:
          restrictions = {
            'deliveryRequired': true,
            'authorizedParticipants': ['delivery_warehouses', 'licensed_processors'],
            'description': 'Physical delivery rights - requires delivery capacity',
          };
          break;
      }

      return {
        'success': true,
        'tokenId': tokenId.toString(),
        'currentPhase': currentPhase.name,
        'restrictions': restrictions,
        'isTransferable': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Utility methods
  double _getCoverageRate(InsuranceTier tier) {
    switch (tier) {
      case InsuranceTier.bronze: return 0.5;   // 50%
      case InsuranceTier.silver: return 0.6;   // 60%
      case InsuranceTier.gold: return 0.7;    // 70%
      case InsuranceTier.platinum: return 0.8; // 80%
    }
  }

  double _getPremiumRate(InsuranceTier tier) {
    switch (tier) {
      case InsuranceTier.bronze: return 0.03;   // 3%
      case InsuranceTier.silver: return 0.025;  // 2.5%
      case InsuranceTier.gold: return 0.02;     // 2%
      case InsuranceTier.platinum: return 0.015; // 1.5%
    }
  }

  double _calculateWeightedMedian(List<double> values, List<double> weights) {
    // Simplified weighted median calculation
    final sortedPairs = <List<double>>[];
    for (int i = 0; i < values.length; i++) {
      sortedPairs.add([values[i], weights[i]]);
    }
    
    sortedPairs.sort((a, b) => a[0].compareTo(b[0]));
    
    double cumulativeWeight = 0;
    for (final pair in sortedPairs) {
      cumulativeWeight += pair[1];
      if (cumulativeWeight >= 0.5) {
        return pair[0];
      }
    }
    
    return sortedPairs.last[0];
  }

  double _calculateConsensusConfidence(List<double> values, double consensus) {
    if (values.isEmpty) return 0.0;
    
    double totalDeviation = 0;
    for (final value in values) {
      totalDeviation += (value - consensus).abs();
    }
    
    final averageDeviation = totalDeviation / values.length;
    final confidence = 1.0 - (averageDeviation / consensus);
    
    return confidence.clamp(0.0, 1.0);
  }

  // Placeholder methods for blockchain interactions
  Future<bool> _checkKYCStatus(String address) async => true;
  Future<double> _getTokenHoldings(String address) async => 0.0;
  Future<double> _getDailyTransferVolume(String address) async => 0.0;
  Future<bool> _checkHarvestPhaseAuthorization(String address) async => false;
  Future<bool> _checkDeliveryCapacity(String address) async => false;
}
