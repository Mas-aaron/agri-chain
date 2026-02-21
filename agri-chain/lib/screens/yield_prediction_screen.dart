import 'package:flutter/material.dart';

import 'package:agri_chain/services/yield_api_service.dart';
import 'package:agri_chain/widgets/modern_ui.dart';
import 'package:agri_chain/config/app_config.dart';

class YieldPredictionScreen extends StatefulWidget {
  const YieldPredictionScreen({super.key});

  @override
  State<YieldPredictionScreen> createState() => _YieldPredictionScreenState();
}

class _YieldPredictionScreenState extends State<YieldPredictionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nitrogenCtrl = TextEditingController(text: '80');
  final _phosphorusCtrl = TextEditingController(text: '40');
  final _potassiumCtrl = TextEditingController(text: '45');
  final _temperatureCtrl = TextEditingController(text: '26');
  final _humidityCtrl = TextEditingController(text: '65');
  final _phCtrl = TextEditingController(text: '6.5');
  final _rainfallCtrl = TextEditingController(text: '650');
  final _pesticideCtrl = TextEditingController(text: '15');

  PredictAndTokenizeResponse? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nitrogenCtrl.dispose();
    _phosphorusCtrl.dispose();
    _potassiumCtrl.dispose();
    _temperatureCtrl.dispose();
    _humidityCtrl.dispose();
    _phCtrl.dispose();
    _rainfallCtrl.dispose();
    _pesticideCtrl.dispose();
    super.dispose();
  }

  double _asDouble(String v, {double fallback = 0}) {
    return double.tryParse(v.trim()) ?? fallback;
  }

  Future<void> _predictAndTokenize() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final req = YieldPredictionRequest(
      nitrogen: _asDouble(_nitrogenCtrl.text),
      phosphorus: _asDouble(_phosphorusCtrl.text),
      potassium: _asDouble(_potassiumCtrl.text),
      temperature: _asDouble(_temperatureCtrl.text),
      humidity: _asDouble(_humidityCtrl.text),
      ph: _asDouble(_phCtrl.text),
      rainfall: _asDouble(_rainfallCtrl.text),
      pesticide: _asDouble(_pesticideCtrl.text),
    );

    try {
      final api = YieldApiService.fromBaseUrl(AppConfig.apiBaseUrl);
      final resp = await api.predictAndTokenize(req);
      if (!mounted) return;
      setState(() {
        _result = resp;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Yield prediction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ImageHeroCard(
            assetPath: 'assets/images/beautiful-shot-cornfield-with-blue-sky.jpg',
            title: 'Yield forecast',
            subtitle: 'Predict yield and tokenize on blockchain.',
          ),
          const SizedBox(height: 12),

          if (_error != null) ...[
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade800))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Input Form ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science_outlined, color: scheme.primary),
                        const SizedBox(width: 10),
                        Text('Soil Chemistry',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('From soil test results (NPK + pH)', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _numField(_nitrogenCtrl, 'Nitrogen (N)', 'kg/ha')),
                      const SizedBox(width: 12),
                      Expanded(child: _numField(_phosphorusCtrl, 'Phosphorus (P)', 'kg/ha')),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _numField(_potassiumCtrl, 'Potassium (K)', 'kg/ha')),
                      const SizedBox(width: 12),
                      Expanded(child: _numField(_phCtrl, 'pH Level', 'pH')),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Icon(Icons.thermostat_outlined, color: scheme.primary),
                      const SizedBox(width: 10),
                      Text('Weather & Environment',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _numField(_temperatureCtrl, 'Temperature', '°C')),
                      const SizedBox(width: 12),
                      Expanded(child: _numField(_humidityCtrl, 'Humidity', '%')),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _numField(_rainfallCtrl, 'Rainfall', 'mm')),
                      const SizedBox(width: 12),
                      Expanded(child: _numField(_pesticideCtrl, 'Pesticide', 'kg/ha')),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _predictAndTokenize,
                        icon: const Icon(Icons.auto_graph_outlined),
                        label: Text(_loading ? 'Processing…' : 'Predict & Tokenize'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Prediction Result ──
          if (_result != null) ...[
            Card(
              color: scheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.insights_outlined, color: scheme.primary),
                      const SizedBox(width: 10),
                      Text('ML Prediction',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      '${_result!.predictedYield.toStringAsFixed(0)} kg/ha',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text('Model: ${_result!.model}  •  Confidence: ${(_result!.confidence * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Token Card ──
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.token_outlined, color: Colors.amber.shade800),
                      const SizedBox(width: 10),
                      Text('Yield Token Created',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800, color: Colors.amber.shade900)),
                    ]),
                    const SizedBox(height: 12),
                    _tokenRow('Token ID', _result!.token.tokenId),
                    _tokenRow('Asset ID', _result!.token.assetId),
                    _tokenRow('Tokens', _result!.token.tokenAmount.toStringAsFixed(0)),
                    _tokenRow('Value', '\$${_result!.token.currentValue.toStringAsFixed(2)}'),
                    _tokenRow('Status', _result!.token.status),
                    const SizedBox(height: 8),
                    Text(_result!.message, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label, String suffix) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (v) => _asDouble(v ?? '') <= 0 ? 'Required' : null,
    );
  }

  Widget _tokenRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
