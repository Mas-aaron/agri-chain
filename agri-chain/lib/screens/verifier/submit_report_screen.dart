import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class SubmitReportScreen extends StatefulWidget {
  final Map<String, dynamic> asset;
  const SubmitReportScreen({super.key, required this.asset});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _yieldCtl = TextEditingController();
  final _confidenceCtl = TextEditingController(text: '0.85');
  final _notesCtl = TextEditingController();
  String _dataSource = 'INSPECTOR';
  String _measurementMethod = 'Direct Weighing';
  bool _submitting = false;

  static const _sources = ['SATELLITE', 'INSPECTOR', 'GOVERNMENT', 'COOPERATIVE'];
  static const _methods = ['Direct Weighing', 'Sample Estimation', 'Drone Survey', 'Satellite Analysis'];

  Future<void> _submit() async {
    final yieldVal = double.tryParse(_yieldCtl.text);
    final confVal = double.tryParse(_confidenceCtl.text);

    if (yieldVal == null || yieldVal <= 0) {
      _showSnack('Please enter a valid yield value.');
      return;
    }
    if (confVal == null || confVal < 0 || confVal > 1) {
      _showSnack('Confidence must be between 0.0 and 1.0');
      return;
    }

    setState(() => _submitting = true);
    try {
      final prov = context.read<VerifierProvider>();
      final result = await prov.submitReport(
        assetId: widget.asset['asset_id'],
        yieldValue: yieldVal,
        confidence: confVal,
        dataSource: _dataSource,
        measurementMethod: _measurementMethod,
        notes: _notesCtl.text.trim(),
      );

      final consensus = result['consensus_formed'] == true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(consensus
                ? 'Report submitted! Consensus has been formed.'
                : 'Report submitted successfully.'),
            backgroundColor: consensus ? Colors.green : null,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final assetId = widget.asset['asset_id'] ?? 'Unknown';
    final crop = widget.asset['crop_type'] ?? 'Maize';
    final season = widget.asset['season']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Asset info ───────────────────────────────
            GradientHeroCard(
              icon: Icons.grass,
              title: assetId,
              subtitle: '$crop \u2022 Season $season',
              colors: [
                scheme.primary.withOpacity(0.12),
                Colors.orange.withOpacity(0.08),
              ],
            ),
            const SizedBox(height: 24),

            // ── Form ─────────────────────────────────────
            const SectionHeader(title: 'Yield Report'),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                children: [
                  TextField(
                    controller: _yieldCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Measured Yield (kg)',
                      prefixIcon: Icon(Icons.scale),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confidenceCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Confidence (0.0 - 1.0)',
                      prefixIcon: Icon(Icons.tune),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _dataSource,
                    decoration: const InputDecoration(
                      labelText: 'Data Source',
                      prefixIcon: Icon(Icons.source_outlined),
                    ),
                    items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _dataSource = v!),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _measurementMethod,
                    decoration: const InputDecoration(
                      labelText: 'Measurement Method',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() => _measurementMethod = v!),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesCtl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.notes),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Submitting...' : 'Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
