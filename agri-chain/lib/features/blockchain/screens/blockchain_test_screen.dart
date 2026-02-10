import 'package:flutter/material.dart';
import 'package:agri_chain/features/blockchain/services/blockchain_test_service.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class BlockchainTestScreen extends StatefulWidget {
  const BlockchainTestScreen({super.key});

  @override
  State<BlockchainTestScreen> createState() => _BlockchainTestScreenState();
}

class _BlockchainTestScreenState extends State<BlockchainTestScreen> {
  final BlockchainTestService _testService = BlockchainTestService();
  
  bool _isRunning = false;
  Map<String, dynamic>? _testResults;
  String? _currentTest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blockchain Tests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConfigurationInfo(),
            const SizedBox(height: 24),
            _buildTestControls(),
            const SizedBox(height: 24),
            if (_testResults != null) ...[
              _buildTestResults(),
              const SizedBox(height: 24),
            ],
            if (_isRunning) _buildRunningTest(),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationInfo() {
    final config = _testService.getConfigurationInfo();
    
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blockchain Configuration',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Provider', config['blockchainProvider']),
          _buildInfoRow('Contract Address', config['contractAddress']),
          _buildInfoRow('Chain ID', config['chainId']),
          _buildInfoRow('Web3 Enabled', config['enableWeb3Integration'].toString()),
          _buildInfoRow('Connected', config['isConnected'].toString()),
          if (config['userAddress'] != null)
            _buildInfoRow('Address', config['userAddress']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestControls() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Controls',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runAllTests,
              icon: _isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running Tests...' : 'Run All Tests'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isRunning ? null : _runYieldTokenTest,
                  icon: const Icon(Icons.token),
                  label: const Text('Test Token Creation'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isRunning ? null : _clearResults,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Results'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestResults() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Results',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...(_testResults?.entries.map((entry) => _buildTestResult(entry)) ?? []),
        ],
      ),
    );
  }

  Widget _buildTestResult(MapEntry<String, dynamic> entry) {
    final result = entry.value as Map<String, dynamic>;
    final success = result['success'] as bool;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: success ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: success ? Colors.green[200]! : Colors.red[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green[600] : Colors.red[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                entry.key,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: success ? Colors.green[800] : Colors.red[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            result['message'],
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: success ? Colors.green[700] : Colors.red[700],
            ),
          ),
          if (result['balance'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Balance: ${result['balance']} ETH',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (result['gasPrice'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Gas Price: ${result['gasPrice']} Gwei',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (result['transactionHash'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'TX: ${result['transactionHash']}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRunningTest() {
    return ModernCard(
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Running: $_currentTest',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait while tests complete...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _currentTest = 'Initializing...';
    });

    try {
      final results = await _testService.runAllTests();
      
      if (mounted) {
        setState(() {
          _testResults = results;
          _isRunning = false;
          _currentTest = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _currentTest = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test execution failed: $e')),
        );
      }
    }
  }

  Future<void> _runYieldTokenTest() async {
    setState(() {
      _isRunning = true;
      _currentTest = 'Testing Yield Token Creation...';
    });

    try {
      final result = await _testService.testYieldTokenCreation(
        farmerId: 'TEST_FARMER_001',
        yieldAmount: BigInt.from(1000),
        cropType: 'Corn',
      );
      
      if (mounted) {
        setState(() {
          _testResults = {'yield_token_test': result};
          _isRunning = false;
          _currentTest = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _currentTest = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yield token test failed: $e')),
        );
      }
    }
  }

  void _clearResults() {
    setState(() {
      _testResults = null;
    });
    _testService.clearTestData();
  }
}
