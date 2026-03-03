// Submit yield report form for an asset.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';

class SubmitReportScreen extends StatefulWidget {
  final Map<String, dynamic> asset;
  const SubmitReportScreen({super.key, required this.asset});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _yieldCtl = TextEditingController();
  final _confidenceCtl = TextEditingController(text: '0.85');
  final _notesCtl = TextEditingController();
  String _source = 'INSPECTOR';
  String? _method;
  bool _submitting = false;

  static const _sources = ['GOVERNMENT', 'UNIVERSITY', 'SATELLITE', 'INSPECTOR', 'COOPERATIVE'];
  static const _methods = [
    'Direct Weighing',
    'Sample Harvest',
    'Satellite Imagery',
    'Drone Survey',
    'Farmer Report',
    'Processor Data',
  ];

  @override
  void dispose() {
    _yieldCtl.dispose();
    _confidenceCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final asset = widget.asset;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Yield Report'),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _submitting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting report…'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Asset info ───────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Asset Details',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary)),
                            const Divider(),
                            _infoRow('Asset ID', asset['asset_id'] ?? '—'),
                            _infoRow('Crop Type', asset['crop_type'] ?? '—'),
                            _infoRow('Season', '${asset['season'] ?? '—'}'),
                            _infoRow('Predicted Yield',
                                '${asset['predicted_yield'] ?? '—'} kg'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Form fields ─────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Yield Measurement',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary)),
                            const Divider(),
                            TextFormField(
                              controller: _yieldCtl,
                              decoration: const InputDecoration(
                                labelText: 'Actual Yield (kg)',
                                hintText: 'e.g. 4200',
                                prefixIcon: Icon(Icons.scale),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (double.tryParse(v) == null) return 'Invalid number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confidenceCtl,
                              decoration: const InputDecoration(
                                labelText: 'Confidence (0.0–1.0)',
                                hintText: '0.85',
                                prefixIcon: Icon(Icons.verified),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final val = double.tryParse(v);
                                if (val == null || val < 0 || val > 1) {
                                  return 'Must be 0.0–1.0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _source,
                              decoration: const InputDecoration(
                                labelText: 'Data Source',
                                prefixIcon: Icon(Icons.source),
                              ),
                              items: _sources
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) => setState(() => _source = v!),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _method,
                              decoration: const InputDecoration(
                                labelText: 'Measurement Method',
                                prefixIcon: Icon(Icons.straighten),
                              ),
                              items: _methods
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (v) => setState(() => _method = v),
                              validator: (v) => v == null ? 'Select a method' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesCtl,
                              decoration: const InputDecoration(
                                labelText: 'Notes (optional)',
                                prefixIcon: Icon(Icons.notes),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _submit,
                                icon: const Icon(Icons.send),
                                label: const Text('Submit Report'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final prov = context.read<VerifierProvider>();
      final res = await prov.submitReport(
        assetId: widget.asset['asset_id'],
        submittedYield: double.parse(_yieldCtl.text),
        confidence: double.parse(_confidenceCtl.text),
        dataSource: _source,
        measurementMethod: _method ?? '',
        notes: _notesCtl.text,
      );

      if (!mounted) return;

      final consensusFormed = res['consensus_formed'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(consensusFormed
              ? '✅ Report submitted — Consensus formed!'
              : '✅ Report submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
