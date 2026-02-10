import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/features/blockchain/providers/blockchain_provider.dart';
import 'package:agri_chain/features/blockchain/services/advanced_token_service.dart';
import 'package:agri_chain/features/blockchain/config/blockchain_config.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class AdvancedTokenizationScreen extends StatefulWidget {
  const AdvancedTokenizationScreen({super.key});

  @override
  State<AdvancedTokenizationScreen> createState() => _AdvancedTokenizationScreenState();
}

class _AdvancedTokenizationScreenState extends State<AdvancedTokenizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdvancedTokenService _tokenService = AdvancedTokenService();
  
  final _farmerIdCtrl = TextEditingController();
  final _yieldAmountCtrl = TextEditingController();
  final _cropTypeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _harvestDateCtrl = TextEditingController();
  
  String _selectedCropType = CropTypes.corn;
  AdvancedTokenService.InsuranceTier _selectedInsuranceTier = AdvancedTokenService.InsuranceTier.silver;
  DateTime? _harvestDate;
  bool _isTokenizing = false;
  Map<String, dynamic>? _tokenizationResult;
  String? _error;

  @override
  void dispose() {
    _farmerIdCtrl.dispose();
    _yieldAmountCtrl.dispose();
    _cropTypeCtrl.dispose();
    _locationCtrl.dispose();
    _harvestDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _tokenizeYield() async {
    if (!_formKey.currentState!.validate() || _harvestDate == null) return;

    setState(() {
      _isTokenizing = true;
      _error = null;
      _tokenizationResult = null;
    });

    try {
      final result = await _tokenService.createTransferableYieldToken(
        farmerId: _farmerIdCtrl.text.trim(),
        cropType: _selectedCropType,
        predictedYield: double.parse(_yieldAmountCtrl.text),
        harvestDate: _harvestDate!,
        insuranceTier: _selectedInsuranceTier,
      );

      if (result['success'] as bool) {
        setState(() {
          _tokenizationResult = result;
        });
        
        // Refresh blockchain provider
        if (mounted) {
          final blockchainProvider = context.read<BlockchainProvider>();
          await blockchainProvider.refresh();
        }
      } else {
        setState(() {
          _error = result['error'] as String?;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Tokenization failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTokenizing = false;
        });
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _tokenizationResult = null;
      _error = null;
      _harvestDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Tokenization'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTokenizationInfo(),
            const SizedBox(height: 24),
            _buildTokenizationForm(),
            if (_tokenizationResult != null) ...[
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

  Widget _buildTokenizationInfo() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.token, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advanced Yield Tokenization',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Create transferable yield tokens with comprehensive risk management',
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
          _buildPhaseInfo(),
        ],
      ),
    );
  }

  Widget _buildPhaseInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Token Lifecycle Phases:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildPhaseItem(
          phase: 'Phase 1: Predicted',
          description: 'Free trading with KYC requirements',
          color: Colors.blue,
        ),
        _buildPhaseItem(
          phase: 'Phase 2: Harvesting',
          description: 'Restricted trading to authorized participants',
          color: Colors.orange,
        ),
        _buildPhaseItem(
          phase: 'Phase 3: Settled',
          description: 'Physical delivery rights',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildPhaseItem({
    required String phase,
    required String description,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$phase - $description',
              style: Theme.of(context).textTheme.bodySmall,
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
                labelText: 'Predicted Yield Amount (kg)',
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
            
            // Harvest Date
            InkWell(
              onTap: _selectHarvestDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expected Harvest Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _harvestDate != null
                      ? '${_harvestDate!.day}/${_harvestDate!.month}/${_harvestDate!.year}'
                      : 'Select harvest date',
                  style: TextStyle(
                    color: _harvestDate != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Insurance Tier
            Text(
              'Insurance Protection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...AdvancedTokenService.InsuranceTier.values.map((tier) {
              return RadioListTile<AdvancedTokenService.InsuranceTier>(
                title: Text(_getInsuranceTierName(tier)),
                subtitle: Text(_getInsuranceTierDescription(tier)),
                value: tier,
                groupValue: _selectedInsuranceTier,
                onChanged: (value) {
                  setState(() {
                    _selectedInsuranceTier = value!;
                  });
                },
              );
            }),
            const SizedBox(height: 24),
            
            // Tokenize Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTokenizing ? null : _tokenizeYield,
                icon: _isTokenizing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.token),
                label: Text(_isTokenizing ? 'Tokenizing...' : 'Create Transferable Token'),
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
    final result = _tokenizationResult!;
    
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
                        'Token Created Successfully!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your yield has been tokenized with comprehensive protection',
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
            _buildTokenDetails(result),
            if (result['insurancePolicy'] != null) ...[
              const SizedBox(height: 16),
              _buildInsuranceDetails(result['insurancePolicy']),
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
                    label: const Text('Create Another'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenDetails(Map<String, dynamic> result) {
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
            'Token Details:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Token ID', result['tokenId']),
          _buildDetailRow('Crop Type', result['cropType']),
          _buildDetailRow('Predicted Yield', '${result['predictedYield']} kg'),
          _buildDetailRow('Current Phase', result['currentPhase']),
          _buildDetailRow('Harvest Date', result['harvestDate']),
        ],
      ),
    );
  }

  Widget _buildInsuranceDetails(Map<String, dynamic> policy) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insurance Policy:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Policy ID', policy['policyId']),
          _buildDetailRow('Coverage Rate', '${policy['coverageRate']}%'),
          _buildDetailRow('Premium', '${policy['premium']} ETH'),
          _buildDetailRow('Tier', policy['tier']),
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
              style: Theme.of(context).textTheme.bodySmall,
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

  Future<void> _selectHarvestDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now().add(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && picked != _harvestDate) {
      setState(() {
        _harvestDate = picked;
        _harvestDateCtrl.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  String _getInsuranceTierName(AdvancedTokenService.InsuranceTier tier) {
    switch (tier) {
      case AdvancedTokenService.InsuranceTier.bronze:
        return 'Bronze';
      case AdvancedTokenService.InsuranceTier.silver:
        return 'Silver';
      case AdvancedTokenService.InsuranceTier.gold:
        return 'Gold';
      case AdvancedTokenService.InsuranceTier.platinum:
        return 'Platinum';
    }
  }

  String _getInsuranceTierDescription(AdvancedTokenService.InsuranceTier tier) {
    switch (tier) {
      case AdvancedTokenService.InsuranceTier.bronze:
        return '50% coverage, 3% premium';
      case AdvancedTokenService.InsuranceTier.silver:
        return '60% coverage, 2.5% premium';
      case AdvancedTokenService.InsuranceTier.gold:
        return '70% coverage, 2% premium';
      case AdvancedTokenService.InsuranceTier.platinum:
        return '80% coverage, 1.5% premium';
    }
  }
}
