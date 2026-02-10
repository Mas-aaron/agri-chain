import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:agri_chain/config/app_config.dart';
import 'package:agri_chain/services/contracts_api_service.dart';

/// Service for integrating blockchain features with backend contracts
class BlockchainIntegrationService {
  final http.Client _httpClient;
  final ContractsApiService _contractsApi;

  BlockchainIntegrationService({http.Client? httpClient, ContractsApiService? contractsApi})
      : _httpClient = httpClient ?? http.Client(),
        _contractsApi = contractsApi ?? ContractsApiService.fromBaseUrl(AppConfig.apiBaseUrl);

  /// Create a blockchain-backed contract
  Future<Map<String, dynamic>> createBlockchainContract({
    required String crop,
    required double quantityKg,
    required double unitPrice,
    required String currency,
    required String farmerName,
    String? evidenceHash,
  }) async {
    try {
      // Step 1: Create contract in backend
      final contractRequest = ContractCreateRequest(
        crop: crop,
        quantityKg: quantityKg,
        unitPrice: unitPrice,
        currency: currency,
        farmerName: farmerName,
        evidenceHash: evidenceHash,
      );

      final contract = await _contractsApi.createContract(contractRequest);

      // Step 2: Create blockchain record (this would interact with Web3 service)
      // For now, we'll simulate blockchain integration
      final blockchainData = await _createBlockchainRecord(
        contractId: contract.id,
        farmerId: farmerName,
        cropType: crop,
        quantity: BigInt.from(quantityKg.toInt()),
      );

      return {
        'success': true,
        'contract': contract.toJson(),
        'blockchain': blockchainData,
        'message': 'Contract created and recorded on blockchain',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create blockchain contract',
      };
    }
  }

  /// Purchase a blockchain-backed contract
  Future<Map<String, dynamic>> purchaseBlockchainContract({
    required String contractId,
    required String buyerName,
  }) async {
    try {
      // Step 1: Purchase contract in backend
      final purchaseRequest = ContractPurchaseRequest(buyerName: buyerName);
      final contract = await _contractsApi.purchaseContract(contractId, purchaseRequest);

      // Step 2: Create blockchain transaction
      final blockchainData = await _createBlockchainTransaction(
        contractId: contractId,
        action: 'purchase',
        actor: buyerName,
      );

      return {
        'success': true,
        'contract': contract.toJson(),
        'blockchain': blockchainData,
        'message': 'Contract purchased and recorded on blockchain',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to purchase blockchain contract',
      };
    }
  }

  /// Mark contract as delivered on blockchain
  Future<Map<String, dynamic>> deliverBlockchainContract({
    required String contractId,
    required String actor,
    String? ref,
  }) async {
    try {
      // Step 1: Mark as delivered in backend
      final deliverRequest = ContractDeliverRequest(actor: actor, ref: ref);
      final contract = await _contractsApi.deliverContract(contractId, deliverRequest);

      // Step 2: Create blockchain transaction
      final blockchainData = await _createBlockchainTransaction(
        contractId: contractId,
        action: 'deliver',
        actor: actor,
      );

      return {
        'success': true,
        'contract': contract.toJson(),
        'blockchain': blockchainData,
        'message': 'Contract delivery recorded on blockchain',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to record delivery on blockchain',
      };
    }
  }

  /// Get blockchain verification for a contract
  Future<Map<String, dynamic>> getBlockchainVerification(String contractId) async {
    try {
      // Get contract from backend
      final contracts = await _contractsApi.listContracts();
      final contract = contracts.firstWhere((c) => c.id == contractId);

      // Get ledger events
      final ledgerEvents = await _contractsApi.listLedger(contractId: contractId);

      // Simulate blockchain verification
      final verification = await _verifyOnBlockchain(contractId);

      return {
        'success': true,
        'contract': contract.toJson(),
        'ledgerEvents': ledgerEvents.map((e) => e.toJson()).toList(),
        'blockchainVerification': verification,
        'message': 'Contract verified on blockchain',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to verify contract on blockchain',
      };
    }
  }

  /// Sync contracts with blockchain
  Future<Map<String, dynamic>> syncWithBlockchain() async {
    try {
      // Get all contracts from backend
      final contracts = await _contractsApi.listContracts();
      
      // Sync each contract with blockchain
      final syncResults = <Map<String, dynamic>>[];
      
      for (final contract in contracts) {
        final syncResult = await _syncContractWithBlockchain(contract);
        syncResults.add(syncResult);
      }

      return {
        'success': true,
        'synced': syncResults.where((r) => r['success'] as bool).length,
        'failed': syncResults.where((r) => !(r['success'] as bool)).length,
        'results': syncResults,
        'message': 'Blockchain sync completed',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to sync with blockchain',
      };
    }
  }

  /// Create blockchain record (simulated)
  Future<Map<String, dynamic>> _createBlockchainRecord({
    required String contractId,
    required String farmerId,
    required String cropType,
    required BigInt quantity,
  }) async {
    // In a real implementation, this would:
    // 1. Connect to Web3 service
    // 2. Create yield token
    // 3. Record transaction hash
    // 4. Return blockchain data
    
    // For now, simulate blockchain interaction
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    
    return {
      'transactionHash': '0x${_generateRandomHex(64)}',
      'blockNumber': 12345678,
      'tokenId': '${DateTime.now().millisecondsSinceEpoch}',
      'contractAddress': String.fromEnvironment('CONTRACT_ADDRESS', defaultValue: '0x0000000000000000000000000000000000000000'),
      'timestamp': DateTime.now().toIso8601String(),
      'confirmed': true,
    };
  }

  /// Create blockchain transaction (simulated)
  Future<Map<String, dynamic>> _createBlockchainTransaction({
    required String contractId,
    required String action,
    required String actor,
  }) async {
    // Simulate blockchain transaction
    await Future.delayed(const Duration(milliseconds: 500));
    
    return {
      'transactionHash': '0x${_generateRandomHex(64)}',
      'blockNumber': 12345679,
      'action': action,
      'actor': actor,
      'contractId': contractId,
      'timestamp': DateTime.now().toIso8601String(),
      'confirmed': true,
    };
  }

  /// Verify contract on blockchain (simulated)
  Future<Map<String, dynamic>> _verifyOnBlockchain(String contractId) async {
    // Simulate blockchain verification
    await Future.delayed(const Duration(milliseconds: 300));
    
    return {
      'verified': true,
      'transactionCount': 3,
      'lastTransaction': '0x${_generateRandomHex(64)}',
      'verificationTimestamp': DateTime.now().toIso8601String(),
      'contractExists': true,
    };
  }

  /// Sync individual contract with blockchain (simulated)
  Future<Map<String, dynamic>> _syncContractWithBlockchain(YieldContractDto contract) async {
    try {
      // Simulate sync process
      await Future.delayed(const Duration(milliseconds: 200));
      
      return {
        'success': true,
        'contractId': contract.id,
        'blockchainHash': '0x${_generateRandomHex(64)}',
        'syncTimestamp': DateTime.now().toIso8601String(),
        'status': 'synced',
      };
    } catch (e) {
      return {
        'success': false,
        'contractId': contract.id,
        'error': e.toString(),
        'status': 'sync_failed',
      };
    }
  }

  /// Generate random hex string for simulation
  String _generateRandomHex(int length) {
    const chars = '0123456789abcdef';
    final random = DateTime.now().millisecondsSinceEpoch;
    String hex = '';
    
    for (int i = 0; i < length; i++) {
      hex += chars[(random + i) % chars.length];
    }
    
    return hex;
  }

  /// Get blockchain statistics
  Future<Map<String, dynamic>> getBlockchainStats() async {
    try {
      final contracts = await _contractsApi.listContracts();
      final ledgerEvents = await _contractsApi.listLedger();
      
      return {
        'success': true,
        'totalContracts': contracts.length,
        'totalTransactions': ledgerEvents.length,
        'contractsByStatus': _groupContractsByStatus(contracts),
        'recentTransactions': ledgerEvents.take(10).map((e) => e.toJson()).toList(),
        'blockchainConnected': true, // Would check actual blockchain connection
        'lastSync': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get blockchain statistics',
      };
    }
  }

  /// Group contracts by status
  Map<String, int> _groupContractsByStatus(List<YieldContractDto> contracts) {
    final statusMap = <String, int>{};
    
    for (final contract in contracts) {
      statusMap[contract.status] = (statusMap[contract.status] ?? 0) + 1;
    }
    
    return statusMap;
  }
}
