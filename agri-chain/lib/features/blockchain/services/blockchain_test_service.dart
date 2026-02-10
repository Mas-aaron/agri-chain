import 'package:flutter/foundation.dart';
import 'web3_service.dart';
import '../config/blockchain_config.dart';

/// Service for testing blockchain functionality
class BlockchainTestService {
  final Web3Service _web3Service = Web3Service();

  /// Run comprehensive blockchain tests
  Future<Map<String, dynamic>> runAllTests() async {
    final results = <String, dynamic>{};
    
    // Test 1: Initialize Web3
    results['initialize'] = await _testInitialize();
    
    // Test 2: Wallet Connection
    if (results['initialize']['success']) {
      results['wallet_connection'] = await _testWalletConnection();
    }
    
    // Test 3: Balance Query
    if (_web3Service.isConnected) {
      results['balance_query'] = await _testBalanceQuery();
    }
    
    // Test 4: Gas Price
    results['gas_price'] = await _testGasPrice();
    
    // Test 5: Contract Interaction (if connected)
    if (_web3Service.isConnected) {
      results['contract_interaction'] = await _testContractInteraction();
    }
    
    return results;
  }

  /// Test Web3 initialization
  Future<Map<String, dynamic>> _testInitialize() async {
    try {
      final success = await _web3Service.initialize();
      return {
        'success': success,
        'message': success ? 'Web3 initialized successfully' : 'Web3 initialization failed',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Web3 initialization error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Test wallet connection
  Future<Map<String, dynamic>> _testWalletConnection() async {
    try {
      final success = await _web3Service.connectWallet();
      return {
        'success': success,
        'message': success ? 'Wallet connected successfully' : 'Wallet connection failed',
        'address': _web3Service.userAddress,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Wallet connection error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Test balance query
  Future<Map<String, dynamic>> _testBalanceQuery() async {
    try {
      if (_web3Service.userAddress == null) {
        return {
          'success': false,
          'message': 'No wallet address available',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      final balance = await _web3Service.getBalance(_web3Service.userAddress!);
      return {
        'success': true,
        'message': 'Balance query successful',
        'balance': balance,
        'address': _web3Service.userAddress,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Balance query error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Test gas price query
  Future<Map<String, dynamic>> _testGasPrice() async {
    try {
      final gasPrice = await _web3Service.getGasPrice();
      return {
        'success': true,
        'message': 'Gas price query successful',
        'gasPrice': gasPrice,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gas price query error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Test contract interaction
  Future<Map<String, dynamic>> _testContractInteraction() async {
    try {
      // Test token info query (this should work even without creating tokens)
      final tokenInfo = await _web3Service.getTokenInfo(BigInt.from(1));
      
      return {
        'success': true,
        'message': 'Contract interaction test successful',
        'contractAddress': BlockchainConfig.contractAddress,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Contract interaction error: $e',
        'contractAddress': BlockchainConfig.contractAddress,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Test yield token creation
  Future<Map<String, dynamic>> testYieldTokenCreation({
    required String farmerId,
    required BigInt yieldAmount,
    required String cropType,
  }) async {
    try {
      if (!_web3Service.isConnected) {
        return {
          'success': false,
          'message': 'Wallet not connected',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      final txHash = await _web3Service.createYieldToken(
        farmerId: farmerId,
        yieldAmount: yieldAmount,
        cropType: cropType,
      );

      return {
        'success': true,
        'message': 'Yield token creation successful',
        'transactionHash': txHash,
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
      final status = await _web3Service.getTransactionStatus(txHash);
      
      return {
        'success': true,
        'message': 'Transaction status query successful',
        'transactionHash': txHash,
        'confirmed': status,
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
      'isConnected': _web3Service.isConnected,
      'userAddress': _web3Service.userAddress,
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
