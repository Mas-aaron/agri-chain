import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:agri_chain/config/app_config.dart';

/// Service for Web3 and blockchain interactions
class Web3Service {
  late Web3Client _client;
  Credentials? _credentials;
  EthereumAddress? _contractAddress;
  DeployedContract? _contract;
  
  String? _userAddress;
  bool _isConnected = false;

  String? get userAddress => _userAddress;
  bool get isConnected => _isConnected;

  /// Initialize Web3 connection
  Future<bool> initialize() async {
    try {
      _client = Web3Client(AppConfig.blockchainRpcUrl, http.Client());
      
      // Load contract ABI and address
      await _loadContract();
      
      // Try to restore existing wallet
      await _restoreWallet();
      
      _isConnected = true;
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

    // Contract address would be loaded from environment or config
    final contractAddr = EthereumAddress.fromHex(
      String.fromEnvironment('CONTRACT_ADDRESS', defaultValue: '0x0000000000000000000000000000000000000000')
    );
    
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
      _credentials = EthPrivateKey.fromSeed(bip39.mnemonicToSeed(mnemonic));
      _userAddress = _credentials!.address.hex;
    }
  }

  /// Connect wallet (create new if none exists)
  Future<bool> connectWallet() async {
    try {
      if (_credentials == null) {
        // Generate new mnemonic and wallet
        final mnemonic = bip39.generateMnemonic();
        final privateKey = EthPrivateKey.fromSeed(bip39.mnemonicToSeed(mnemonic));
        
        // Save mnemonic securely
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('wallet_mnemonic', mnemonic);
        
        _credentials = privateKey;
      }
      
      _userAddress = _credentials!.address.hex;
      _isConnected = true;
      return true;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Get user's wallet balance
  Future<String> getBalance(String address) async {
    try {
      if (!_isConnected || _client == null) {
        throw Exception('Web3 not initialized');
      }
      
      final addr = EthereumAddress.fromHex(address);
      final balance = await _client.getBalance(addr);
      
      // Convert from Wei to Ether
      final etherBalance = balance.getValueInUnit(EtherUnit.ether);
      return etherBalance.toStringAsFixed(6);
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
      if (!_isConnected || _credentials == null || _contract == null) {
        throw Exception('Web3 not properly initialized');
      }

      final function = _contract!.function('createYieldToken');
      final transaction = Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [farmerId, yieldAmount, cropType],
        maxGas: 100000,
      );

      final signedTx = await _client.sendTransaction(
        _credentials!,
        transaction,
        chainId: int.parse(String.fromEnvironment('CHAIN_ID', defaultValue: '1')),
      );

      return signedTx;
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
      if (!_isConnected || _credentials == null || _contract == null) {
        throw Exception('Web3 not properly initialized');
      }

      final to = EthereumAddress.fromHex(toAddress);
      final function = _contract!.function('transferToken');
      final transaction = Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [to, tokenId],
        maxGas: 100000,
      );

      final signedTx = await _client.sendTransaction(
        _credentials!,
        transaction,
        chainId: int.parse(String.fromEnvironment('CHAIN_ID', defaultValue: '1')),
      );

      return signedTx;
    } catch (e) {
      throw Exception('Failed to transfer token: $e');
    }
  }

  /// Get token information
  Future<Map<String, dynamic>> getTokenInfo(BigInt tokenId) async {
    try {
      if (!_isConnected || _client == null || _contract == null) {
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

  /// Sign a transaction (legacy method)
  Future<String> signTransaction({
    required String from,
    required String to,
    required String amount,
  }) async {
    try {
      if (!_isConnected || _credentials == null) {
        throw Exception('Wallet not connected');
      }

      final fromAddr = EthereumAddress.fromHex(from);
      final toAddr = EthereumAddress.fromHex(to);
      final amountWei = BigInt.parse(amount) * BigInt.from(10).pow(18);

      final transaction = Transaction(
        from: fromAddr,
        to: toAddr,
        value: EtherAmount.fromUnitAndValue(EtherUnit.wei, amountWei),
        maxGas: 21000,
      );

      final signedTx = await _client.signTransaction(_credentials!, transaction);
      return signedTx;
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
      final signedTx = await signTransaction(from: from, to: to, amount: amount);
      
      final txHash = await _client.sendRawTransaction(signedTx);
      return txHash;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  /// Get transaction status
  Future<bool> getTransactionStatus(String txHash) async {
    try {
      if (!_isConnected || _client == null) {
        throw Exception('Web3 not initialized');
      }

      final receipt = await _client.getTransactionReceipt(txHash);
      return receipt != null && receipt.status == true;
    } catch (e) {
      return false;
    }
  }

  /// Disconnect wallet
  void disconnect() {
    _userAddress = null;
    _isConnected = false;
    _credentials = null;
  }

  /// Check if address is valid
  static bool isValidAddress(String address) {
    try {
      EthereumAddress.fromHex(address);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Format address for display (0x1234...5678)
  static String formatAddress(String address) {
    if (!isValidAddress(address)) return 'Invalid';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  /// Get current gas price
  Future<String> getGasPrice() async {
    try {
      if (!_isConnected || _client == null) {
        throw Exception('Web3 not initialized');
      }

      final gasPrice = await _client.getGasPrice();
      return gasPrice.getValueInUnit(EtherUnit.gwei).toStringAsFixed(2);
    } catch (e) {
      throw Exception('Failed to get gas price: $e');
    }
  }

  /// Estimate gas for transaction
  Future<BigInt> estimateGas({
    required String to,
    String? data,
  }) async {
    try {
      if (!_isConnected || _client == null || _credentials == null) {
        throw Exception('Web3 not initialized');
      }

      final toAddr = EthereumAddress.fromHex(to);
      final gasEstimate = await _client.estimateGas(
        to: toAddr,
        from: _credentials!.address,
        data: data != null ? hexToBytes(data) : null,
      );
      
      return gasEstimate;
    } catch (e) {
      throw Exception('Failed to estimate gas: $e');
    }
  }
}

/// Helper function to convert hex string to bytes
List<int> hexToBytes(String hex) {
  hex = hex.startsWith('0x') ? hex.substring(2) : hex;
  return List.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}
