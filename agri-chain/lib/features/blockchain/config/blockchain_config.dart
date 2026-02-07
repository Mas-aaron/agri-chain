/// Blockchain configuration constants
class BlockchainConfig {
  // API Configuration
  static const String apiBaseUrl = 'http://localhost:3000/api';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Blockchain Configuration
  static const String blockchainProvider = 'http://localhost:8545';
  static const String contractAddress =
      '0x0000000000000000000000000000000000000000';
  static const String chainId = '1';

  // Features
  static const bool enableWeb3Integration = true;
  static const bool enableOracle = true;
  static const bool enableTrading = true;

  // Cache Duration
  static const Duration cacheDuration = Duration(minutes: 5);
  static const Duration shortCacheDuration = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;

  // Error Messages
  static const String networkError =
      'Network connection failed. Please check your internet.';
  static const String serverError = 'Server error. Please try again later.';
  static const String validationError =
      'Invalid input. Please check your data.';
}

/// Asset Status Constants
class AssetStatus {
  static const String pending = 'PENDING';
  static const String predicted = 'PREDICTED';
  static const String verified = 'VERIFIED';
  static const String tradeable = 'TRADEABLE';
  static const String settled = 'SETTLED';
  static const String archived = 'ARCHIVED';

  static const List<String> all = [
    pending,
    predicted,
    verified,
    tradeable,
    settled,
    archived,
  ];
}

/// Crop Types
class CropTypes {
  static const String wheat = 'Wheat';
  static const String corn = 'Corn';
  static const String rice = 'Rice';
  static const String soybean = 'Soybean';
  static const String barley = 'Barley';

  static const List<String> all = [
    wheat,
    corn,
    rice,
    soybean,
    barley,
  ];
}
