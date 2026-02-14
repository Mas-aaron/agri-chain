import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/blockchain_config.dart';

/// Service for Web3 and blockchain interactions
class Web3Service {
  final http.Client _httpClient;

  String? _userAddress;
  bool _isConnected = false;

  String? get userAddress => _userAddress;
  bool get isConnected => _isConnected;

  Web3Service({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  Uri _u(String path) => Uri.parse('${BlockchainConfig.apiBaseUrl}$path');

  /// Initialize Web3 connection
  Future<bool> initialize() async {
    try {
      final res = await _httpClient
          .get(_u('/wallet/status'), headers: {'Accept': 'application/json'})
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        _isConnected = false;
        _userAddress = null;
        return false;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _isConnected = (data['isConnected'] as bool?) ?? false;
      _userAddress = (data['address'] as String?)?.isNotEmpty == true ? data['address'] as String : null;
      return true;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Load contract ABI and address
  Future<void> _loadContract() async {
    // AgriYield Contract ABI (simplified)
    const contractAbi = '''[
      {
        "name": "createYieldToken",
        "type": "function",
        "inputs": [
          {"name": "farmerId", "type": "string"},
          {"name": "yieldAmount", "type": "uint256"},
          {"name": "cropType", "type": "string"}
        ],
        "outputs": [{"name": "tokenId", "type": "uint256"}]
      },
      {
        "name": "transferToken",
        "type": "function",
        "inputs": [
          {"name": "to", "type": "address"},
          {"name": "tokenId", "type": "uint256"}
        ],
        "outputs": [{"name": "success", "type": "bool"}]
      },
      {
        "name": "getTokenInfo",
        "type": "function",
        "inputs": [{"name": "tokenId", "type": "uint256"}],
        "outputs": [
          {"name": "farmerId", "type": "string"},
          {"name": "yieldAmount", "type": "uint256"},
          {"name": "cropType", "type": "string"}
        ]
      }
    ]''';

    // Contract address must be compile-time provided for web builds.
    final contractAddr = EthereumAddress.fromHex(_kContractAddressHex);
    
    _contractAddress = contractAddr;
    _contract = DeployedContract(
      ContractAbi.fromJson(contractAbi, 'AgriYieldToken'),
      contractAddr,
    );
  }

  /// Restore existing wallet or create new one
  Future<void> _restoreWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final mnemonic = prefs.getString('wallet_mnemonic');
    
    if (mnemonic != null && bip39.validateMnemonic(mnemonic)) {
      final seed = bip39.mnemonicToSeed(mnemonic);
      final master = await ED25519_HD_KEY.getMasterKeyFromSeed(seed);
      final privateKey = bytesToHex(master.key);
      
      _credentials = EthPrivateKey.fromHex(privateKey);
      _userAddress = _credentials!.address.hex;
    }
  }

  EthPrivateKey _privateKeyFromMnemonic(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    // NOTE: This is a simplified deterministic derivation (seed[0..31]).
    // For production wallets you should derive using BIP32/BIP44 paths.
    final keyBytes = Uint8List.fromList(seed.sublist(0, 32));
    return EthPrivateKey(keyBytes);
  }

  /// Connect wallet (create new if none exists)
  Future<bool> connectWallet() async {
    try {
      final res = await _httpClient
          .post(_u('/wallet/connect'), headers: {'Accept': 'application/json'})
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        _isConnected = false;
        return false;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _isConnected = (data['success'] as bool?) ?? true;
      _userAddress = (data['address'] as String?) ?? _userAddress;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Get user's wallet balance
  Future<String> getBalance(String address) async {
    try {
      if (!_isConnected) {
        throw Exception('Wallet not connected');
      if (!_isConnected) {
        throw Exception('Web3 not initialized');
      }

      final res = await _httpClient
          .get(_u('/wallet/balance'), headers: {'Accept': 'application/json'})
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Balance query failed');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final balance = (data['balance'] as String?) ?? '0.0';
      return balance;
    } catch (e) {
      throw Exception('Failed to get balance: $e');
    }
  }

  /// Create yield token on blockchain
  Future<String> createYieldToken({
    required String farmerId,
    required BigInt yieldAmount,
    required String cropType,
  }) async {
    try {
      if (!_isConnected) {
        throw Exception('Wallet not connected');
      }

      final res = await _httpClient
          .post(
            _u('/yield-token'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'farmerId': farmerId,
              'yieldAmount': yieldAmount.toString(),
              'cropType': cropType,
            }),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Tokenization failed');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['transactionHash'] as String?) ?? '';
    } catch (e) {
      throw Exception('Failed to create yield token: $e');
    }
  }

  /// Transfer yield token
  Future<String> transferYieldToken({
    required String toAddress,
    required BigInt tokenId,
  }) async {
    try {
      if (!_isConnected) {
        throw Exception('Wallet not connected');
      }

      final res = await _httpClient
          .post(
            _u('/advanced/transfer'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'tokenId': tokenId.toString(),
              'toAddress': toAddress,
              'amount': 1.0,
            }),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Transfer failed');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['transactionHash'] as String?) ?? '';
    } catch (e) {
      throw Exception('Failed to transfer token: $e');
    }
  }

  /// Get token information
  Future<Map<String, dynamic>> getTokenInfo(BigInt tokenId) async {
    try {
      final res = await _httpClient
          .get(_u('/token-info/${tokenId.toString()}'), headers: {'Accept': 'application/json'})
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Token info query failed');
      }

      return jsonDecode(res.body) as Map<String, dynamic>;
      if (!_isConnected || _contract == null) {
        throw Exception('Web3 not properly initialized');
      }

      final function = _contract!.function('getTokenInfo');
      final result = await _client.call(
        contract: _contract!,
        function: function,
        params: [tokenId],
      );

      return {
        'farmerId': result[0] as String,
        'yieldAmount': result[1] as BigInt,
        'cropType': result[2] as String,
      };
    } catch (e) {
      throw Exception('Failed to get token info: $e');
    }
  }

  /// Sign a transaction
  Future<String> signTransaction({
    required String from,
    required String to,
    required String amount,
  }) async {
    throw Exception('Signing is handled by the backend');
    try {
      if (!_isConnected || _credentials == null) {
        throw Exception('Wallet not connected');
      }

      // Optional sanity check: ensure the provided "from" matches current wallet.
      final fromAddr = EthereumAddress.fromHex(from);
      if (fromAddr != _credentials!.address) {
        throw Exception('From address does not match connected wallet');
      }
      final toAddr = EthereumAddress.fromHex(to);
      final amountWei = BigInt.parse(amount) * BigInt.from(10).pow(18);

      final transaction = Transaction(
        to: toAddr,
        value: EtherAmount.fromUnitAndValue(EtherUnit.wei, amountWei),
        maxGas: 21000,
      );

      final signedTx = await _client.signTransaction(_credentials!, transaction, chainId: 1);
      return bytesToHex(signedTx);
    } catch (e) {
      throw Exception('Failed to sign transaction: $e');
    }
  }

  /// Send a transaction (legacy method)
  Future<String> sendTransaction({
    required String from,
    required String to,
    required String amount,
  }) async {
    try {
      final res = await _httpClient
          .post(
            _u('/transactions/send'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'from': from, 'to': to, 'amount': amount}),
          )
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Transaction failed');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['transactionHash'] as String?) ?? '';
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  /// Get transaction status
  Future<bool> getTransactionStatus(String txHash) async {
    try {
      final res = await _httpClient
          .get(_u('/transactions/$txHash'), headers: {'Accept': 'application/json'})
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['confirmed'] as bool?) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Disconnect wallet
  void disconnect() {
    _userAddress = null;
    _isConnected = false;
    _httpClient.post(_u('/wallet/disconnect'), headers: {'Accept': 'application/json'});
  }

  /// Check if address is valid
  static bool isValidAddress(String address) {
    final a = address.trim();
    final re = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return re.hasMatch(a);
  }

  /// Format address for display (0x1234...5678)
  static String formatAddress(String address) {
    if (!isValidAddress(address)) return 'Invalid';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  /// Get current gas price
  Future<String> getGasPrice() async {
    try {
      final res = await _httpClient
          .get(_u('/gas-price'), headers: {'Accept': 'application/json'})
          .timeout(BlockchainConfig.apiTimeout);

      if (res.statusCode != 200) {
        throw Exception('Gas price query failed');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['gasPrice'] as String?) ?? '0.0';
    } catch (e) {
      throw Exception('Failed to get gas price: $e');
    }
  }

  /// Estimate gas for transaction
  Future<BigInt> estimateGas({
    required String to,
    String? data,
  }) async {
    return BigInt.from(21000);
  }
}

/// Helper function to convert hex string to bytes
List<int> hexToBytes(String hex) {
  hex = hex.startsWith('0x') ? hex.substring(2) : hex;
  return List.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}

/// Helper function to convert bytes to hex string
String bytesToHex(List<int> bytes) {
  return '0x' + bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
