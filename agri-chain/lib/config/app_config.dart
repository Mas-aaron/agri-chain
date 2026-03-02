import 'package:flutter/foundation.dart';

const String _kFlutterEnv = String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');

const String _kApiBaseUrlOverride = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://101.44.10.153:8000',
);

const String _kBlockchainRpcOverride = String.fromEnvironment(
  'BLOCKCHAIN_RPC_URL',
  defaultValue: 'http://10.0.2.2:8500',
);

const bool _kEnableBlockchain = bool.fromEnvironment('ENABLE_BLOCKCHAIN', defaultValue: true);
const bool _kEnableDebugLogs = bool.fromEnvironment('ENABLE_DEBUG_LOGS', defaultValue: false);

const String _kDatabasePath = String.fromEnvironment('DATABASE_PATH', defaultValue: 'agrichain.db');

/// Application configuration with environment-based settings
class AppConfig {
  // API Configuration
  static const String _defaultApiBaseUrl = 'http://101.44.10.153:8000';
  static const String _prodApiBaseUrl = 'https://api.agrichain.com';

  // Blockchain Explorer
  /// Base URL for the Huawei BCS blockchain explorer.
  /// Append /assets/{assetId} or /transactions/{txId} to form a direct link.
  static String get explorerBaseUrl {
    return switch (_kFlutterEnv) {
      'production' => 'https://explorer.agrichain.com',
      _ => '${apiBaseUrl}/blockchain/explorer',
    };
  }
  
  static String get apiBaseUrl {
    final raw = switch (_kFlutterEnv) {
      'production' => _prodApiBaseUrl,
      'staging' => 'https://staging-api.agrichain.com',
      _ => _kApiBaseUrlOverride.isNotEmpty ? _kApiBaseUrlOverride : _defaultApiBaseUrl,
    };

    if (kIsWeb) {
      return raw.replaceFirst('http://10.0.2.2:', 'http://localhost:');
    }

    return raw;
  }

  // Blockchain Configuration
  static const String _defaultBlockchainRpc = 'http://10.0.2.2:8000';
  static const String _prodBlockchainRpc = 'https://mainnet.infura.io/v3/YOUR-PROJECT-ID';
  
  static String get blockchainRpcUrl {
    final raw = switch (_kFlutterEnv) {
      'production' => _prodBlockchainRpc,
      'staging' => 'https://goerli.infura.io/v3/YOUR-PROJECT-ID',
      _ => _kBlockchainRpcOverride.isNotEmpty ? _kBlockchainRpcOverride : _defaultBlockchainRpc,
    };

    if (kIsWeb) {
      return raw.replaceFirst('http://10.0.2.2:', 'http://localhost:');
    }

    return raw;
  }

  // App Environment
  static String get environment {
    return _kFlutterEnv;
  }

  static bool get isDebugMode {
    return environment == 'development';
  }

  static bool get isProductionMode {
    return environment == 'production';
  }

  // Feature Flags
  static bool get enableBlockchainFeatures {
    return _kEnableBlockchain;
  }

  static bool get enableDebugLogs {
    return _kEnableDebugLogs;
  }

  // Timeout Configuration
  static Duration get apiTimeout {
    return switch (_kFlutterEnv) {
      'production' => const Duration(seconds: 30),
      'staging' => const Duration(seconds: 20),
      _ => const Duration(seconds: 10),
    };
  }

  // Database Configuration
  static String get databasePath {
    return _kDatabasePath;
  }
}
