import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:agri_chain/config/app_config.dart';
import 'web3_service.dart';

/// Advanced token service implementing sophisticated transferability and risk management
class AdvancedTokenService {
  final Web3Service _web3Service;
  final http.Client _httpClient;

  AdvancedTokenService({Web3Service? web3Service, http.Client? httpClient})
      : _web3Service = web3Service ?? Web3Service(),
        _httpClient = httpClient ?? http.Client();

  /// Token phases for transfer restrictions
  enum TokenPhase {
    predicted,    // Phase 1: Pre-harvest (free trading)
    harvesting,   // Phase 2: During harvest (restricted trading)
    settled       // Phase 3: Post-harvest (physical delivery/settlement)
  }

  /// Insurance tiers
  enum InsuranceTier {
    bronze,       // 50% coverage, 3% premium
    silver,       // 60% coverage, 2.5% premium
    gold,         // 70% coverage, 2% premium
    platinum      // 80% coverage, 1.5% premium
  }

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

      // Convert to blockchain units
      final predictedYieldWei = BigInt.from(predictedYield * 1e18);
      final harvestTimestamp = harvestDate.millisecondsSinceEpoch ~/ 1000;

      // Create token through smart contract
      final contract = await _web3Service.getContract();
      final result = await contract.call(
        'mintYieldToken',
        [
          EthereumAddress.fromHex(_web3Service.userAddress!),
          cropType,
          predictedYieldWei,
          BigInt.from(harvestTimestamp),
        ],
        credentials: _web3Service.getCredentials(),
      );

      final tokenId = result[0] as BigInt;

      // Create insurance policy
      final insuranceResult = await createInsurancePolicy(
        tokenId: tokenId,
        farmerId: farmerId,
        predictedYield: predictedYield,
        tier: insuranceTier,
      );

      return {
        'success': true,
        'tokenId': tokenId.toString(),
        'farmerId': farmerId,
        'cropType': cropType,
        'predictedYield': predictedYield,
        'harvestDate': harvestDate.toIso8601String(),
        'currentPhase': TokenPhase.predicted.name,
        'insurancePolicy': insuranceResult,
        'transactionHash': result[1]?.toString(),
      };
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

      // Validate transfer eligibility
      final validationResult = await _validateTransfer(
        tokenId: tokenId,
        fromAddress: _web3Service.userAddress!,
        toAddress: toAddress,
        amount: amount,
      );

      if (!validationResult['isValid']) {
        return {
          'success': false,
          'error': validationResult['error'],
          'message': 'Transfer validation failed',
        };
      }

      // Execute transfer
      final contract = await _web3Service.getContract();
      final amountWei = BigInt.from(amount * 1e18);
      
      final result = await contract.call(
        'safeTransferFrom',
        [
          EthereumAddress.fromHex(_web3Service.userAddress!),
          EthereumAddress.fromHex(toAddress),
          tokenId,
          amountWei,
          transferMetadata ?? '',
        ],
        credentials: _web3Service.getCredentials(),
      );

      return {
        'success': true,
        'tokenId': tokenId.toString(),
        'fromAddress': _web3Service.userAddress,
        'toAddress': toAddress,
        'amount': amount,
        'transactionHash': result.toString(),
        'phase': validationResult['currentPhase'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Token transfer failed',
      };
    }
  }

  /// Validate transfer according to phase-based restrictions
  Future<Map<String, dynamic>> _validateTransfer({
    required BigInt tokenId,
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    try {
      final contract = await _web3Service.getContract();
      
      // Get token info and phase
      final tokenInfo = await contract.call('getTokenInfo', [tokenId]);
      final phase = await contract.call('tokenPhases', [tokenId]);
      
      final currentPhase = TokenPhase.values[int.parse(phase.toString())];
      final predictedYield = double.parse(tokenInfo[4].toString()) / 1e18;
      final harvestDate = DateTime.fromMillisecondsSinceEpoch(
        int.parse(tokenInfo[6].toString()) * 1000,
      );

      // Phase-based validation
      switch (currentPhase) {
        case TokenPhase.predicted:
          return await _validatePredictedPhaseTransfer(
            fromAddress: fromAddress,
            toAddress: toAddress,
            amount: amount,
            predictedYield: predictedYield,
          );
          
        case TokenPhase.harvesting:
          return await _validateHarvestingPhaseTransfer(
            fromAddress: fromAddress,
            toAddress: toAddress,
            amount: amount,
          );
          
        case TokenPhase.settled:
          return await _validateSettledPhaseTransfer(
            fromAddress: fromAddress,
            toAddress: toAddress,
            amount: amount,
          );
      }
    } catch (e) {
      return {
        'isValid': false,
        'error': e.toString(),
        'currentPhase': null,
      };
    }
  }

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
      final contract = await _web3Service.getInsuranceContract();
      
      // Calculate insurance parameters
      final coverageRate = _getCoverageRate(tier);
      final premiumRate = _getPremiumRate(tier);
      final insuredAmount = predictedYield * 1e18; // Assuming 1 ETH per kg
      final premium = insuredAmount * premiumRate / 10000;
      
      // Create policy
      final result = await contract.call(
        'createPolicy',
        [
          EthereumAddress.fromHex(_web3Service.userAddress!),
          tokenId,
          BigInt.from(predictedYield * 1e18),
          BigInt.from(insuredAmount),
          BigInt.from(tier.index),
        ],
        credentials: _web3Service.getCredentials(),
        value: BigInt.from(premium),
      );

      final policyId = result[0] as BigInt;

      return {
        'success': true,
        'policyId': policyId.toString(),
        'tokenId': tokenId.toString(),
        'farmerId': farmerId,
        'predictedYield': predictedYield,
        'insuredAmount': insuredAmount / 1e18,
        'premium': premium / 1e18,
        'coverageRate': coverageRate,
        'tier': tier.name,
        'transactionHash': result[1]?.toString(),
      };
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
      final contract = await _web3Service.getContract();
      
      // Submit actual yield to oracle
      final oracleReport = await _submitYieldToOracle(
        tokenId: tokenId,
        actualYield: actualYield,
        sourceIds: oracleSourceIds ?? ['government', 'satellite', 'local'],
      );

      if (!oracleReport['isVerified']) {
        return {
          'success': false,
          'error': 'Oracle consensus not reached',
          'confidence': oracleReport['confidence'],
        };
      }

      // Process actual yield on blockchain
      final result = await contract.call(
        'processActualYield',
        [
          tokenId,
          BigInt.from(actualYield * 1e18),
        ],
        credentials: _web3Service.getCredentials(),
      );

      // Calculate discrepancy
      final tokenInfo = await contract.call('getTokenInfo', [tokenId]);
      final predictedYield = double.parse(tokenInfo[4].toString()) / 1e18;
      final discrepancy = predictedYield - actualYield;
      final discrepancyPercentage = (discrepancy / predictedYield) * 100;

      // Trigger insurance if needed
      Map<String, dynamic>? insuranceClaim;
      if (discrepancyPercentage > 5) {
        insuranceClaim = await _triggerInsuranceClaim(tokenId, discrepancy);
      }

      return {
        'success': true,
        'tokenId': tokenId.toString(),
        'predictedYield': predictedYield,
        'actualYield': actualYield,
        'discrepancy': discrepancy,
        'discrepancyPercentage': discrepancyPercentage,
        'oracleReport': oracleReport,
        'insuranceClaim': insuranceClaim,
        'transactionHash': result.toString(),
      };
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
      final contract = await _web3Service.getInsuranceContract();
      
      // Get policy for this token
      final policy = await contract.call('getInsurancePolicy', [tokenId]);
      if (policy[0] == BigInt.zero) {
        return null; // No policy exists
      }

      // Process claim
      final result = await contract.call(
        'processDiscrepancyClaim',
        [
          policy[0], // policyId
          BigInt.from(discrepancy * 1e18),
          [1, 2, 3], // oracle source IDs
        ],
        credentials: _web3Service.getCredentials(),
      );

      return {
        'policyId': policy[0].toString(),
        'claimAmount': double.parse(result[0].toString()) / 1e18,
        'discrepancyPercentage': double.parse(result[1].toString()),
        'transactionHash': result[2]?.toString(),
      };
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
      final contract = await _web3Service.getContract();
      
      final tokenInfo = await contract.call('getTokenInfo', [tokenId]);
      final phase = await contract.call('tokenPhases', [tokenId]);
      final currentPhase = TokenPhase.values[int.parse(phase.toString())];

      return {
        'tokenId': tokenId.toString(),
        'farmerId': tokenInfo[1],
        'cropType': tokenInfo[2],
        'predictedYield': double.parse(tokenInfo[3].toString()) / 1e18,
        'actualYield': double.parse(tokenInfo[4].toString()) / 1e18,
        'harvestDate': DateTime.fromMillisecondsSinceEpoch(
          int.parse(tokenInfo[5].toString()) * 1000,
        ).toIso8601String(),
        'currentPhase': currentPhase.name,
        'originalFarmer': tokenInfo[6].toString(),
        'createdAt': DateTime.fromMillisecondsSinceEpoch(
          int.parse(tokenInfo[7].toString()) * 1000,
        ).toIso8601String(),
        'settledAt': int.parse(tokenInfo[8].toString()) > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                int.parse(tokenInfo[8].toString()) * 1000,
              ).toIso8601String()
            : null,
        'isActive': tokenInfo[9],
      };
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
