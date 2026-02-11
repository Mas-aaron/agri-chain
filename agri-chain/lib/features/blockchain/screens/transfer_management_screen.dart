import 'package:flutter/material.dart';
import 'package:agri_chain/features/blockchain/services/advanced_token_service.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class TransferManagementScreen extends StatefulWidget {
  const TransferManagementScreen({super.key});

  @override
  State<TransferManagementScreen> createState() => _TransferManagementScreenState();
}

class _TransferManagementScreenState extends State<TransferManagementScreen> {
  final AdvancedTokenService _tokenService = AdvancedTokenService();
  final _formKey = GlobalKey<FormState>();
  
  final _tokenIdCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  
  bool _isTransferring = false;
  Map<String, dynamic>? _transferResult;
  Map<String, dynamic>? _tokenInfo;
  String? _error;

  @override
  void dispose() {
    _tokenIdCtrl.dispose();
    _recipientCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    final tokenId = _tokenIdCtrl.text.trim();
    if (tokenId.isEmpty) return;

    try {
      final result = await _tokenService.getTokenInfo(BigInt.parse(tokenId));
      if (result['success'] as bool) {
        setState(() {
          _tokenInfo = result;
        });
      } else {
        setState(() {
          _tokenInfo = null;
          _error = 'Token not found';
        });
      }
    } catch (e) {
      setState(() {
        _tokenInfo = null;
        _error = 'Invalid token ID';
      });
    }
  }

  Future<void> _executeTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTransferring = true;
      _error = null;
      _transferResult = null;
    });

    try {
      final result = await _tokenService.transferTokens(
        tokenId: BigInt.parse(_tokenIdCtrl.text.trim()),
        toAddress: _recipientCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text),
        transferMetadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'purpose': 'yield_token_transfer',
        },
      );

      setState(() {
        _transferResult = result;
      });
    } catch (e) {
      setState(() {
        _error = 'Transfer failed: $e';
      });
    } finally {
      setState(() {
        _isTransferring = false;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _transferResult = null;
      _tokenInfo = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransferInfo(),
            const SizedBox(height: 24),
            _buildTransferForm(),
            if (_tokenInfo != null) ...[
              const SizedBox(height: 24),
              _buildTokenInfoSection(),
            ],
            if (_transferResult != null) ...[
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

  Widget _buildTransferInfo() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Token Transfer Management',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Transfer yield tokens with phase-based restrictions and validation',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTransferRules(),
        ],
      ),
    );
  }

  Widget _buildTransferRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transfer Rules:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildRuleItem(
          icon: Icons.verified_user,
          rule: 'KYC Required',
          description: 'For transfers over 10,000 tokens',
        ),
        _buildRuleItem(
          icon: Icons.account_balance_wallet,
          rule: 'Position Limits',
          description: 'Maximum 100,000 tokens per address',
        ),
        _buildRuleItem(
          icon: Icons.schedule,
          rule: 'Daily Limits',
          description: 'Maximum 50,000 tokens per day',
        ),
        _buildRuleItem(
          icon: Icons.security,
          rule: 'Phase Restrictions',
          description: 'Based on token lifecycle phase',
        ),
      ],
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required String rule,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$rule: $description',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferForm() {
    return ModernCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfer Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Token ID
            TextFormField(
              controller: _tokenIdCtrl,
              decoration: InputDecoration(
                labelText: 'Token ID',
                hintText: 'Enter the token ID to transfer',
                prefixIcon: const Icon(Icons.token),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _validateToken,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter token ID';
                }
                try {
                  BigInt.parse(value.trim());
                } catch (e) {
                  return 'Invalid token ID format';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Recipient Address
            TextFormField(
              controller: _recipientCtrl,
              decoration: const InputDecoration(
                labelText: 'Recipient Address',
                hintText: 'Enter recipient wallet address',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter recipient address';
                }
                if (!value.startsWith('0x') || value.length != 42) {
                  return 'Invalid wallet address format';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Transfer Amount',
                hintText: 'Enter amount to transfer',
                prefixIcon: Icon(Icons.send),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter transfer amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Transfer Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isTransferring || _tokenInfo == null) ? null : _executeTransfer,
                icon: _isTransferring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isTransferring ? 'Transferring...' : 'Execute Transfer'),
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

  Widget _buildTokenInfoSection() {
    if (_tokenInfo == null) return const SizedBox.shrink();
    
    final info = _tokenInfo!;
    final phase = TokenPhase.values.firstWhere(
      (phase) => phase.name == info['currentPhase'],
      orElse: () => TokenPhase.predicted,
    );

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Token Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Token ID', info['tokenId']),
          _buildInfoRow('Crop Type', info['cropType']),
          _buildInfoRow('Predicted Yield', '${info['predictedYield']} kg'),
          _buildInfoRow('Current Phase', _getPhaseDisplayName(phase)),
          _buildInfoRow('Harvest Date', info['harvestDate']),
          if (info['actualYield'] != null)
            _buildInfoRow('Actual Yield', '${info['actualYield']} kg'),
          const SizedBox(height: 12),
          _buildPhaseRestrictions(phase),
        ],
      ),
    );
  }

  Widget _buildPhaseRestrictions(TokenPhase phase) {
    Color phaseColor;
    String restrictions;
    
    switch (phase) {
      case TokenPhase.predicted:
        phaseColor = Colors.blue;
        restrictions = 'Free trading with KYC requirements for large transfers';
        break;
      case TokenPhase.harvesting:
        phaseColor = Colors.orange;
        restrictions = 'Restricted to authorized participants only';
        break;
      case TokenPhase.settled:
        phaseColor = Colors.green;
        restrictions = 'Physical delivery rights - requires delivery capacity';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: phaseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: phaseColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: phaseColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              restrictions,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: phaseColor.withOpacity(0.8),
              ),
            ),
          ),
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

  Widget _buildSuccessSection() {
    final result = _transferResult!;
    
    return ModernCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        'Transfer Successful!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tokens have been transferred successfully',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTransferDetails(result),
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
                    label: const Text('New Transfer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferDetails(Map<String, dynamic> result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer Details:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Token ID', result['tokenId']),
          _buildDetailRow('From Address', result['fromAddress']),
          _buildDetailRow('To Address', result['toAddress']),
          _buildDetailRow('Amount', '${result['amount']} tokens'),
          _buildDetailRow('Phase', result['phase']),
          if (result['transactionHash'] != null)
            _buildDetailRow('Transaction Hash', result['transactionHash']),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
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
                    'Transfer Failed',
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

  String _getPhaseDisplayName(TokenPhase phase) {
    switch (phase) {
      case TokenPhase.predicted:
        return 'Phase 1: Predicted';
      case TokenPhase.harvesting:
        return 'Phase 2: Harvesting';
      case TokenPhase.settled:
        return 'Phase 3: Settled';
    }
  }
}
