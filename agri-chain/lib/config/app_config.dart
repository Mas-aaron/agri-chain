/// Application configuration with environment-based settings
class AppConfig {
  // API Configuration
  static const String _defaultApiBaseUrl = 'http://10.0.2.2:8000';
  static const String _prodApiBaseUrl = 'https://api.agrichain.com';
  
  static String get apiBaseUrl {
    const environment = String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');
    return switch (environment) {
      'production' => _prodApiBaseUrl,
      'staging' => 'https://staging-api.agrichain.com',
      _ => String.fromEnvironment('API_BASE_URL', defaultValue: _defaultApiBaseUrl),
    };
  }

  // Blockchain Configuration
  static const String _defaultBlockchainRpc = 'http://10.0.2.2:8545';
  static const String _prodBlockchainRpc = 'https://mainnet.infura.io/v3/YOUR-PROJECT-ID';
  
  static String get blockchainRpcUrl {
    const environment = String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');
    return switch (environment) {
      'production' => _prodBlockchainRpc,
      'staging' => 'https://goerli.infura.io/v3/YOUR-PROJECT-ID',
      _ => String.fromEnvironment('BLOCKCHAIN_RPC_URL', defaultValue: _defaultBlockchainRpc),
    };
  }

  // App Environment
  static String get environment {
    return String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');
  }

  static bool get isDebugMode {
    return environment == 'development';
  }

  static bool get isProductionMode {
    return environment == 'production';
  }

  // Feature Flags
  static bool get enableBlockchainFeatures {
    return String.fromEnvironment('ENABLE_BLOCKCHAIN', defaultValue: 'true').toLowerCase() == 'true';
  }

  static bool get enableDebugLogs {
    return String.fromEnvironment('ENABLE_DEBUG_LOGS', defaultValue: 'false').toLowerCase() == 'true';
  }

  // Timeout Configuration
  static Duration get apiTimeout {
    const environment = String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');
    return switch (environment) {
      'production' => const Duration(seconds: 30),
      'staging' => const Duration(seconds: 20),
      _ => const Duration(seconds: 10),
    };
  }

  // Database Configuration
  static String get databasePath {
    return String.fromEnvironment('DATABASE_PATH', defaultValue: 'agrichain.db');
  }
}
