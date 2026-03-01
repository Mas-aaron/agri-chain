import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agri_chain/config/app_config.dart';
import 'package:agri_chain/features/blockchain/providers/blockchain_provider.dart';
import 'package:agri_chain/features/blockchain/config/blockchain_config.dart';
import 'package:agri_chain/features/blockchain/models/yield_asset.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class TokenizeYieldScreen extends StatefulWidget {
  const TokenizeYieldScreen({super.key});

  @override
  State<TokenizeYieldScreen> createState() => _TokenizeYieldScreenState();
}

class _TokenizeYieldScreenState extends State<TokenizeYieldScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _regionCtrl = TextEditingController();
  final _soilTypeCtrl = TextEditingController();
  final _rainfallCtrl = TextEditingController();
  final _temperatureCtrl = TextEditingController();
  final _weatherCtrl = TextEditingController();
  final _daysToHarvestCtrl = TextEditingController();
  final _insuranceTierCtrl = TextEditingController();
  
  String _selectedCropType = CropTypes.corn;
  bool _isTokenizing = false;
  String? _txId;
  String? _assetId;
  String? _error;
  bool _showSuccess = false;

  bool _fertilizerUsed = false;
  bool _irrigationUsed = false;

  @override
  void dispose() {
    _regionCtrl.dispose();
    _soilTypeCtrl.dispose();
    _rainfallCtrl.dispose();
    _temperatureCtrl.dispose();
    _weatherCtrl.dispose();
    _daysToHarvestCtrl.dispose();
    _insuranceTierCtrl.dispose();
    super.dispose();
  }

  Future<void> _tokenizeYield() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTokenizing = true;
      _error = null;
      _txId = null;
      _assetId = null;
      _showSuccess = false;
    });

    try {
      final blockchainProvider = context.read<BlockchainProvider>();

      final rainfall = double.parse(_rainfallCtrl.text.trim());
      final temp = double.parse(_temperatureCtrl.text.trim());
      final days = int.parse(_daysToHarvestCtrl.text.trim());
      final insuranceTier = _insuranceTierCtrl.text.trim();

      final res = await blockchainProvider.mintYieldAssetFromPrediction(
        cropType: _selectedCropType,
        insuranceTier: insuranceTier.isEmpty ? null : insuranceTier,
        region: _regionCtrl.text.trim(),
        soilType: _soilTypeCtrl.text.trim(),
        rainfallMm: rainfall,
        temperatureCelsius: temp,
        fertilizerUsed: _fertilizerUsed,
        irrigationUsed: _irrigationUsed,
        weatherCondition: _weatherCtrl.text.trim(),
        daysToHarvest: days,
      );

      if (res == null) {
        throw Exception(blockchainProvider.error ?? 'Mint failed');
      }

      setState(() {
        _assetId = (res['assetId'] ?? '').toString();
        _txId = (res['txId'] ?? '').toString();
        _showSuccess = true;
      });
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

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _txId = null;
      _assetId = null;
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
            Icons.cloud_done,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gateway Connected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Yield minting is performed by the backend (Fabric/BCS).',
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
            
            // Region
            TextFormField(
              controller: _regionCtrl,
              decoration: const InputDecoration(
                labelText: 'Region',
                hintText: 'e.g. Central',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter region';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Soil Type
            TextFormField(
              controller: _soilTypeCtrl,
              decoration: const InputDecoration(
                labelText: 'Soil type',
                hintText: 'e.g. Loamy',
                prefixIcon: Icon(Icons.terrain_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter soil type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Rainfall
            TextFormField(
              controller: _rainfallCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Rainfall (mm)',
                hintText: 'e.g. 120',
                prefixIcon: Icon(Icons.water_drop_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter rainfall';
                }
                final v = double.tryParse(value);
                if (v == null || v < 0) {
                  return 'Please enter a valid rainfall value';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Temperature
            TextFormField(
              controller: _temperatureCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Temperature (°C)',
                hintText: 'e.g. 26',
                prefixIcon: Icon(Icons.thermostat_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter temperature';
                }
                final v = double.tryParse(value);
                if (v == null) {
                  return 'Please enter a valid temperature';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Weather
            TextFormField(
              controller: _weatherCtrl,
              decoration: const InputDecoration(
                labelText: 'Weather',
                hintText: 'e.g. Sunny',
                prefixIcon: Icon(Icons.cloud_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter weather';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Days to Harvest
            TextFormField(
              controller: _daysToHarvestCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Days to Harvest',
                hintText: 'e.g. 120',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter days to harvest';
                }
                final v = int.tryParse(value);
                if (v == null || v < 0) {
                  return 'Please enter a valid days to harvest value';
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

            SwitchListTile(
              value: _fertilizerUsed,
              onChanged: (v) => setState(() => _fertilizerUsed = v),
              title: const Text('Fertilizer used'),
            ),
            SwitchListTile(
              value: _irrigationUsed,
              onChanged: (v) => setState(() => _irrigationUsed = v),
              title: const Text('Irrigation used'),
            ),

            TextFormField(
              controller: _insuranceTierCtrl,
              decoration: const InputDecoration(
                labelText: 'Insurance tier (optional)',
                hintText: 'e.g. silver',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
            ),
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
            if ((_txId ?? '').isNotEmpty || (_assetId ?? '').isNotEmpty) ...[
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
                      'Mint Result:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'assetId: ${_assetId ?? ''}\ntxId: ${_txId ?? ''}',
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
                    onPressed: () async {
                      final explorerUrl = Uri.parse(
                          '${AppConfig.explorerBaseUrl}/assets/${_assetId ?? ''}');
                      if (await canLaunchUrl(explorerUrl)) {
                        await launchUrl(explorerUrl,
                            mode: LaunchMode.externalApplication);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Could not open blockchain explorer')),
                          );
                        }
                      }
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
