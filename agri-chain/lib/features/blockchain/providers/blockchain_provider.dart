import 'package:flutter/foundation.dart';
import '../models/yield_asset.dart';
import '../services/blockchain_api_service.dart';

/// Provider for managing blockchain yield assets and portfolio
class BlockchainProvider extends ChangeNotifier {
  final BlockchainApiService _apiService;

  BlockchainProvider({BlockchainApiService? apiService})
      : _apiService = apiService ?? BlockchainApiService();

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
}
