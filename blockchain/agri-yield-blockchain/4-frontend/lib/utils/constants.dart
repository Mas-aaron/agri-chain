class Constants {
  // API Configuration
  static const String apiBaseUrl = 'http://localhost:3000/api';
  static const String apiTimeout = '30';

  // Blockchain Configuration
  static const String rpcUrl = 'http://localhost:8545';
  static const String chainId = '1337'; // Local development chain

  // Contract Addresses (Update with your deployed contract addresses)
  static const String yieldTokenContractAddress =
      '0x0000000000000000000000000000000000000000';
  static const String farmerRegistryContractAddress =
      '0x0000000000000000000000000000000000000000';

  // App Configuration
  static const String appName = 'AgriYield';
  static const String appVersion = '1.0.0';

  // Crop Types
  static const List<String> cropTypes = [
    'Wheat',
    'Corn',
    'Rice',
    'Soybean',
    'Cotton',
    'Sugarcane',
    'Groundnut',
    'Sunflower',
  ];

  // Status Types
  static const List<String> assetStatus = [
    'PREDICTED',
    'VERIFIED',
    'TOKENIZED',
    'TRADING',
    'SETTLED',
  ];

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;

  // Colors (in hex format for easy reference)
  static const String primaryGreenHex = '#2E7D32';
  static const String accentOrangeHex = '#F57C00';
  static const String accentBlueHex = '#1976D2';
}
