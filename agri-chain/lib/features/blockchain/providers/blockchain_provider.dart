import 'package:flutter/foundation.dart';
import '../models/yield_asset.dart';
import '../services/blockchain_api_service.dart';
import '../services/web3_service.dart';

/// Provider for managing blockchain yield assets and portfolio
class BlockchainProvider extends ChangeNotifier {
  final BlockchainApiService _apiService;
  final Web3Service _web3Service;

  BlockchainProvider({BlockchainApiService? apiService, Web3Service? web3Service})
      : _apiService = apiService ?? BlockchainApiService(),
        _web3Service = web3Service ?? Web3Service();

  // State variables
  List<YieldAsset> _assets = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedFarmerId;
  Map<String, dynamic> _portfolioSummary = {};

  // Getters
  List<YieldAsset> get assets => _assets;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedFarmerId => _selectedFarmerId;
  Map<String, dynamic> get portfolioSummary => _portfolioSummary;

  bool get hasAssets => _assets.isNotEmpty;
  double get totalPortfolioValue =>
      _assets.fold(0.0, (sum, asset) => sum + asset.currentValue);
  double get averageConfidence => _assets.isEmpty
      ? 0.0
      : _assets.fold(0.0, (sum, asset) => sum + asset.confidence) /
          _assets.length;

  /// Initialize provider with farmer ID
  Future<void> initialize(String farmerId) async {
    _selectedFarmerId = farmerId;
    await refresh();
  }

  Future<Map<String, dynamic>?> mintYieldAssetFromPrediction({
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _apiService.mintYieldAssetFromPrediction(
        cropType: cropType,
        insuranceTier: insuranceTier,
        region: region,
        soilType: soilType,
        rainfallMm: rainfallMm,
        temperatureCelsius: temperatureCelsius,
        fertilizerUsed: fertilizerUsed,
        irrigationUsed: irrigationUsed,
        weatherCondition: weatherCondition,
        daysToHarvest: daysToHarvest,
      );
      await refresh();
      return res;
    } catch (e) {
      _error = _parseError(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh yield assets from API
  Future<void> refresh() async {
    if (_selectedFarmerId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _assets = await _apiService.getYieldAssets(_selectedFarmerId!);
      _portfolioSummary =
          await _apiService.getPortfolioSummary(_selectedFarmerId!);
      _error = null;
    } catch (e) {
      _error = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a single asset by ID
  Future<YieldAsset?> getAsset(String assetId) async {
    try {
      return await _apiService.getYieldAsset(assetId);
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return null;
    }
  }

  /// Create a new yield asset
  Future<bool> createAsset(YieldAsset asset) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newAsset = await _apiService.createYieldAsset(asset);
      _assets.add(newAsset);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing asset
  Future<bool> updateAsset(YieldAsset asset) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedAsset =
          await _apiService.updateYieldAsset(asset.assetId, asset);
      final index = _assets.indexWhere((a) => a.assetId == asset.assetId);
      if (index >= 0) {
        _assets[index] = updatedAsset;
      }
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete an asset
  Future<bool> deleteAsset(String assetId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteYieldAsset(assetId);
      _assets.removeWhere((a) => a.assetId == assetId);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Execute a token trade
  Future<bool> executeTrade(
      String assetId, double amount, String tradeType) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.executeTrade(assetId, amount, tradeType);
      await refresh(); // Refresh to get updated data
      return true;
    } catch (e) {
      _error = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear all data and reset state
  void clear() {
    _assets = [];
    _error = null;
    _isLoading = false;
    _selectedFarmerId = null;
    _portfolioSummary = {};
    notifyListeners();
  }

  /// Filter assets by status
  List<YieldAsset> getAssetsByStatus(String status) {
    return _assets.where((asset) => asset.status == status).toList();
  }

  /// Filter assets by crop type
  List<YieldAsset> getAssetsByCropType(String cropType) {
    return _assets.where((asset) => asset.cropType == cropType).toList();
  }

  /// Get assets sorted by value (descending)
  List<YieldAsset> getAssetsValueSorted() {
    final sorted = List<YieldAsset>.from(_assets);
    sorted.sort((a, b) => b.currentValue.compareTo(a.currentValue));
    return sorted;
  }

  /// Parse error messages
  String _parseError(Object error) {
    if (error is Exception) {
      final message = error.toString();
      if (message.contains('SocketException') ||
          message.contains('Connection refused')) {
        return 'Unable to connect to blockchain service. Please check your connection.';
      }
      return message.replaceFirst('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }

  // Blockchain-specific methods
  
  /// Initialize blockchain connection
  Future<bool> initializeBlockchain() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final success = await _web3Service.initialize();
      if (!success) {
        _error = 'Failed to initialize blockchain connection';
        return false;
      }
      
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Connect wallet
  Future<bool> connectWallet() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final success = await _web3Service.connectWallet();
      if (!success) {
        _error = 'Failed to connect wallet';
        return false;
      }
      
      await refresh(); // Refresh assets after wallet connection
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get wallet balance
  Future<String> getWalletBalance() async {
    if (!_web3Service.isConnected || _web3Service.userAddress == null) {
      return '0.0';
    }
    
    try {
      return await _web3Service.getBalance(_web3Service.userAddress!);
    } catch (e) {
      _error = _parseError(e);
      return '0.0';
    }
  }

  /// Create yield token on blockchain
  Future<String?> createYieldToken({
    required String farmerId,
    required BigInt yieldAmount,
    required String cropType,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final txHash = await _web3Service.createYieldToken(
        farmerId: farmerId,
        yieldAmount: yieldAmount,
        cropType: cropType,
      );
      
      await refresh(); // Refresh assets after token creation
      return txHash;
    } catch (e) {
      _error = _parseError(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Transfer yield token
  Future<String?> transferYieldToken({
    required String toAddress,
    required BigInt tokenId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final txHash = await _web3Service.transferYieldToken(
        toAddress: toAddress,
        tokenId: tokenId,
      );
      
      await refresh(); // Refresh assets after transfer
      return txHash;
    } catch (e) {
      _error = _parseError(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get token information
  Future<Map<String, dynamic>?> getTokenInfo(BigInt tokenId) async {
    try {
      return await _web3Service.getTokenInfo(tokenId);
    } catch (e) {
      _error = _parseError(e);
      return null;
    }
  }

  /// Get transaction status
  Future<bool> getTransactionStatus(String txHash) async {
    try {
      return await _web3Service.getTransactionStatus(txHash);
    } catch (e) {
      _error = _parseError(e);
      return false;
    }
  }

  /// Get gas price
  Future<String> getGasPrice() async {
    try {
      return await _web3Service.getGasPrice();
    } catch (e) {
      _error = _parseError(e);
      return '0.0';
    }
  }

  /// Disconnect wallet
  void disconnectWallet() {
    _web3Service.disconnect();
    clear();
  }

  /// Getters for wallet status
  bool get isWalletConnected => _web3Service.isConnected;
  String? get walletAddress => _web3Service.userAddress;
}
