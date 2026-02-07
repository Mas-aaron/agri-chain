import 'package:flutter/material.dart';

import 'package:agri_chain/services/yield_api_service.dart';

class YieldPredictionScreen extends StatefulWidget {
  const YieldPredictionScreen({super.key});

  @override
  State<YieldPredictionScreen> createState() => _YieldPredictionScreenState();
}

class _YieldPredictionScreenState extends State<YieldPredictionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _regionCtrl = TextEditingController();
  final _soilCtrl = TextEditingController();
  final _rainfallCtrl = TextEditingController(text: '650');
  final _tempCtrl = TextEditingController(text: '26');
  final _daysCtrl = TextEditingController(text: '90');

  bool _fertilizer = true;
  bool _irrigation = false;

  String _weather = 'normal';

  double? _predicted;
  String? _message;
  bool _loading = false;
  String? _error;

  static const _defaultApiBaseUrl = 'http://10.0.2.2:8000';

  @override
  void dispose() {
    _regionCtrl.dispose();
    _soilCtrl.dispose();
    _rainfallCtrl.dispose();
    _tempCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  double _asDouble(String v, {double fallback = 0}) {
    return double.tryParse(v.trim()) ?? fallback;
  }

  int _asInt(String v, {int fallback = 0}) {
    return int.tryParse(v.trim()) ?? fallback;
  }

  Future<void> _predict() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final rainfall = _asDouble(_rainfallCtrl.text, fallback: 0);
    final temp = _asDouble(_tempCtrl.text, fallback: 0);
    final days = _asInt(_daysCtrl.text, fallback: 0);

    final req = YieldPredictionRequest(
      region: _regionCtrl.text.trim(),
      soilType: _soilCtrl.text.trim(),
      rainfallMm: rainfall,
      temperatureCelsius: temp,
      fertilizerUsed: _fertilizer,
      irrigationUsed: _irrigation,
      weatherCondition: _weather,
      daysToHarvest: days,
    );

    try {
      final api = YieldApiService.fromBaseUrl(_defaultApiBaseUrl);
      final resp = await api.predict(req);
      if (!mounted) return;
      setState(() {
        _predicted = resp.predictedYield;
        _message = resp.message ?? 'Prediction from server.';
      });
      return;
    } catch (e) {
      // Fallback to offline prediction.
      if (!mounted) return;
      setState(() {
        _error = 'Server unavailable. Showing offline estimate.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }

    // Offline heuristic prediction (static) so the feature works without backend.
    // Returns kg/ha.
    var base = 2400.0;

    // Rainfall effect: ideal ~700mm.
    final rainDelta = (rainfall - 700.0) / 50.0;
    base += (rainDelta.clamp(-6, 6)) * 120.0;

    // Temperature effect: ideal ~26C.
    final tDelta = (temp - 26.0);
    base -= (tDelta.abs().clamp(0, 8)) * 90.0;

    // Inputs effect.
    if (_fertilizer) base += 420.0;
    if (_irrigation) base += 260.0;

    // Weather condition.
    switch (_weather) {
      case 'dry':
        base -= 380.0;
        break;
      case 'wet':
        base -= 220.0;
        break;
      case 'stormy':
        base -= 520.0;
        break;
      default:
        break;
    }

    // Days to harvest: shorter period = less grain fill; very long also penalized.
    if (days < 70) base -= (70 - days) * 35.0;
    if (days > 120) base -= (days - 120) * 20.0;

    final predicted = base.clamp(300.0, 6500.0);

    if (!mounted) return;
    setState(() {
      _predicted = predicted;
      _message = 'Prediction generated offline (demo). Start the FastAPI server to get model-based predictions.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yield prediction'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
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
                        Icon(Icons.agriculture_outlined, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enter field conditions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _regionCtrl,
                      decoration: const InputDecoration(labelText: 'Region'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _soilCtrl,
                      decoration: const InputDecoration(labelText: 'Soil type (e.g. loamy, clay)'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rainfallCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Rainfall (mm)'),
                            validator: (v) {
                              final d = _asDouble(v ?? '');
                              if (d <= 0) return 'Enter rainfall';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tempCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Temperature (°C)'),
                            validator: (v) {
                              final d = _asDouble(v ?? '');
                              if (d <= 0) return 'Enter temperature';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _daysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Days to harvest'),
                      validator: (v) {
                        final d = _asInt(v ?? '');
                        if (d <= 0) return 'Enter days';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _weather,
                      decoration: const InputDecoration(labelText: 'Weather condition'),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'dry', child: Text('Dry')),
                        DropdownMenuItem(value: 'wet', child: Text('Wet')),
                        DropdownMenuItem(value: 'stormy', child: Text('Stormy')),
                      ],
                      onChanged: (v) => setState(() => _weather = v ?? 'normal'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _fertilizer,
                      onChanged: (v) => setState(() => _fertilizer = v),
                      title: const Text('Fertilizer used'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _irrigation,
                      onChanged: (v) => setState(() => _irrigation = v),
                      title: const Text('Irrigation used'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _predict,
                        icon: const Icon(Icons.auto_graph_outlined),
                        label: Text(_loading ? 'Predicting…' : 'Predict yield'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_predicted != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.insights_outlined, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Prediction',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_predicted!.toStringAsFixed(0)} kg/ha',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(_message ?? '', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
