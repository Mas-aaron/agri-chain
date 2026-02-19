import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agri_chain/features/blockchain/providers/blockchain_provider.dart';
import 'package:agri_chain/features/blockchain/services/web3_service.dart';
import 'package:agri_chain/features/blockchain/config/blockchain_config.dart';
import 'package:agri_chain/features/blockchain/widgets/status_badge.dart';
import 'package:agri_chain/widgets/modern_ui.dart';
import 'package:agri_chain/config/app_config.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final Web3Service _web3Service = Web3Service();
  bool _isConnecting = false;
  String? _connectionError;
  String? _mnemonicPhrase;
  bool _showMnemonic = false;

  @override
  void initState() {
    super.initState();
    _initializeWallet();
  }

  Future<void> _initializeWallet() async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    if (kIsWeb || !BlockchainConfig.enableWeb3Integration) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError = null;
        });
      }
      return;
    }

    try {
      final success = await _web3Service.initialize();
      if (mounted) {
        setState(() {
          _isConnecting = false;
          if (!success) {
            _connectionError = 'Failed to initialize wallet';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError = 'Failed to initialize wallet: $e';
        });
      }
    }
  }

  Future<void> _connectWallet() async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      final success = await _web3Service.connectWallet();
      if (success) {
        // Get mnemonic for display (only in development)
        if (AppConfig.isDebugMode) {
          _mnemonicPhrase = await _getStoredMnemonic();
        }
        
        // Update blockchain provider
        if (mounted) {
          final blockchainProvider = context.read<BlockchainProvider>();
          await blockchainProvider.refresh();
        }
      }
    } catch (e) {
      setState(() {
        _connectionError = 'Failed to connect wallet: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<String?> _getStoredMnemonic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('wallet_mnemonic');
    } catch (e) {
      return null;
    }
  }

  Future<void> _disconnectWallet() async {
    try {
      _web3Service.disconnect();
      
      // Clear mnemonic from preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wallet_mnemonic');
      
      setState(() {
        _mnemonicPhrase = null;
        _connectionError = null;
      });
    } catch (e) {
      setState(() {
        _connectionError = 'Failed to disconnect wallet: $e';
      });
    }
  }

  Future<void> _copyAddressToClipboard() async {
    if (_web3Service.userAddress != null) {
      // TODO: Implement clipboard functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blockchain Wallet'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 24),
            if (_web3Service.isConnected) ...[
              _buildWalletInfo(),
              const SizedBox(height: 24),
              _buildWalletActions(),
              if (_mnemonicPhrase != null) ...[
                const SizedBox(height: 24),
                _buildMnemonicSection(),
              ],
            ] else ...[
              _buildConnectWalletSection(),
            ],
            if (_connectionError != null) ...[
              const SizedBox(height: 16),
              _buildErrorSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return ModernCard(
      child: Row(
        children: [
          StatusBadge(
            status: _web3Service.isConnected ? 'Connected' : 'Disconnected',
            isActive: _web3Service.isConnected,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _web3Service.isConnected ? 'Wallet Connected' : 'Wallet Not Connected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _web3Service.isConnected 
                    ? 'Your wallet is ready for blockchain transactions'
                    : 'Connect your wallet to access blockchain features',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletInfo() {
    if (_web3Service.userAddress == null) return const SizedBox.shrink();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet Address',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _copyAddressToClipboard,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Web3Service.formatAddress(_web3Service.userAddress!),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<String>(
            future: _web3Service.getBalance(_web3Service.userAddress!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              
              if (snapshot.hasError) {
                return Text(
                  'Balance: Error loading',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
                );
              }
              
              final balance = snapshot.data ?? '0.0';
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ETH Balance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$balance ETH',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWalletActions() {
    return ModernCard(
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to send transaction screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Send transaction feature coming soon')),
                );
              },
              icon: const Icon(Icons.send),
              label: const Text('Send Transaction'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Navigate to receive transaction screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Receive transaction feature coming soon')),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Receive'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _disconnectWallet,
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect Wallet'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMnemonicSection() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recovery Phrase',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showMnemonic = !_showMnemonic;
                  });
                },
                icon: Icon(_showMnemonic ? Icons.visibility_off : Icons.visibility),
                label: Text(_showMnemonic ? 'Hide' : 'Show'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: _showMnemonic
                ? Text(
                    _mnemonicPhrase ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'monospace',
                      color: Colors.orange[900],
                    ),
                  )
                : Text(
                    '••••••••••••• •••••••••••• ••••••••••••',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: 'monospace',
                      color: Colors.orange[600],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            '⚠️ Save this phrase securely. Anyone with access to this phrase can control your wallet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectWalletSection() {
    return ModernCard(
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Connect Your Wallet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new wallet or import an existing one to start using blockchain features.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connectWallet,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wallet),
              label: Text(_isConnecting ? 'Connecting...' : 'Create New Wallet'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement import wallet functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Import wallet feature coming soon')),
                );
              },
              icon: const Icon(Icons.file_upload),
              label: const Text('Import Existing Wallet'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return ModernCard(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _connectionError ?? 'An error occurred',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
