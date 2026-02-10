import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/features/blockchain/providers/blockchain_provider.dart';
import 'package:agri_chain/features/blockchain/services/web3_service.dart';
import 'package:agri_chain/features/blockchain/config/blockchain_config.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class TokenizeYieldScreen extends StatefulWidget {
  const TokenizeYieldScreen({super.key});

  @override
  State<TokenizeYieldScreen> createState() => _TokenizeYieldScreenState();
}

class _TokenizeYieldScreenState extends State<TokenizeYieldScreen> {
  final _formKey = GlobalKey<FormState>();
  final Web3Service _web3Service = Web3Service();
  
  final _farmerIdCtrl = TextEditingController();
  final _yieldAmountCtrl = TextEditingController();
  final _cropTypeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _seasonCtrl = TextEditingController();
  final _qualityCtrl = TextEditingController();
  
  String _selectedCropType = CropTypes.corn;
  bool _isTokenizing = false;
  String? _txHash;
  String? _error;
  bool _showSuccess = false;

  @override
  void dispose() {
    _farmerIdCtrl.dispose();
    _yieldAmountCtrl.dispose();
    _cropTypeCtrl.dispose();
    _locationCtrl.dispose();
    _seasonCtrl.dispose();
    _qualityCtrl.dispose();
    super.dispose();
  }

  Future<void> _tokenizeYield() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_web3Service.isConnected) {
      setState(() {
        _error = 'Please connect your wallet first';
      });
      return;
    }

    setState(() {
      _isTokenizing = true;
      _error = null;
      _txHash = null;
      _showSuccess = false;
    });

    try {
      final yieldAmount = BigInt.parse(_yieldAmountCtrl.text);
      
      // Create yield token on blockchain
      final txHash = await _web3Service.createYieldToken(
        farmerId: _farmerIdCtrl.text.trim(),
        yieldAmount: yieldAmount,
        cropType: _selectedCropType,
      );

      // Wait for transaction confirmation
      final confirmed = await _waitForTransactionConfirmation(txHash);
      
      if (confirmed) {
        // Refresh blockchain provider
        if (mounted) {
          final blockchainProvider = context.read<BlockchainProvider>();
          await blockchainProvider.refresh();
        }
        
        setState(() {
          _txHash = txHash;
          _showSuccess = true;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to tokenize yield: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTokenizing = false;
        });
      }
    }
  }

  Future<bool> _waitForTransactionConfirmation(String txHash) async {
    int attempts = 0;
    const maxAttempts = 30;
    
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));
      
      try {
        final isConfirmed = await _web3Service.getTransactionStatus(txHash);
        if (isConfirmed) return true;
      } catch (e) {
        // Continue trying
      }
      
      attempts++;
    }
    
    return false;
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _txHash = null;
      _error = null;
      _showSuccess = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tokenize Yield'),
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
            _buildTokenizationForm(),
            if (_showSuccess) ...[
              const SizedBox(height: 24),
              _buildSuccessSection(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 24),
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
          Icon(
            _web3Service.isConnected ? Icons.check_circle : Icons.warning,
            color: _web3Service.isConnected ? Colors.green : Colors.orange,
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
                    ? 'Ready to tokenize your yield'
                    : 'Connect your wallet to tokenize yield',
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

  Widget _buildTokenizationForm() {
    return ModernCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yield Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Farmer ID
            TextFormField(
              controller: _farmerIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Farmer ID',
                hintText: 'Enter your unique farmer identifier',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter farmer ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Yield Amount
            TextFormField(
              controller: _yieldAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Yield Amount (kg)',
                hintText: 'Enter expected yield in kilograms',
                prefixIcon: Icon(Icons.scale),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter yield amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                if (amount > 1000000) {
                  return 'Amount seems too large';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Crop Type
            DropdownButtonFormField<String>(
              value: _selectedCropType,
              decoration: const InputDecoration(
                labelText: 'Crop Type',
                prefixIcon: Icon(Icons.agriculture),
              ),
              items: CropTypes.all.map((crop) {
                return DropdownMenuItem(
                  value: crop,
                  child: Text(crop),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCropType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Location
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Farm Location',
                hintText: 'Enter farm location or coordinates',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            
            // Season
            TextFormField(
              controller: _seasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Season',
                hintText: 'e.g., Spring 2024',
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            
            // Quality Grade
            TextFormField(
              controller: _qualityCtrl,
              decoration: const InputDecoration(
                labelText: 'Quality Grade',
                hintText: 'e.g., Grade A, Premium',
                prefixIcon: Icon(Icons.star),
              ),
            ),
            const SizedBox(height: 24),
            
            // Tokenize Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isTokenizing || !_web3Service.isConnected) ? null : _tokenizeYield,
                icon: _isTokenizing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.token),
                label: Text(_isTokenizing ? 'Tokenizing...' : 'Tokenize Yield'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessSection() {
    return ModernCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yield Tokenized Successfully!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your yield has been recorded on the blockchain',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_txHash != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Hash:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _txHash!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: View on blockchain explorer
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Blockchain explorer coming soon')),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View on Blockchain'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.add),
                    label: const Text('Tokenize Another'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection() {
    return ModernCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tokenization Failed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _error ?? 'An error occurred',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
