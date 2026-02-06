import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;

class Web3Service {
  late Web3Client _client;
  late EthereumAddress _contractAddress;
  late EthereumAddress _userAddress;

  static const String rpcUrl = 'http://localhost:8545';

  Future<void> initialize(
      String contractAddressHex, String userAddressHex) async {
    _client = Web3Client(rpcUrl, http.Client());
    _contractAddress = EthereumAddress.fromHex(contractAddressHex);
    _userAddress = EthereumAddress.fromHex(userAddressHex);
  }

  Web3Client get client => _client;
  EthereumAddress get contractAddress => _contractAddress;
  EthereumAddress get userAddress => _userAddress;

  Future<EtherAmount> getBalance() async {
    try {
      final balance = await _client.getBalance(_userAddress);
      return balance;
    } catch (e) {
      throw Exception('Failed to get balance: $e');
    }
  }

  Future<String> callContractFunction(
    String functionName,
    List<dynamic> params,
  ) async {
    try {
      // This is a placeholder for contract interaction
      // Implement actual contract calls based on your ABI
      return 'success';
    } catch (e) {
      throw Exception('Failed to call contract: $e');
    }
  }

  void dispose() {
    _client.dispose();
  }
}
