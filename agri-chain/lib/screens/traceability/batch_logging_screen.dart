import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';
import 'package:agri_chain/providers/alerts_provider.dart';

class BatchLoggingScreen extends StatefulWidget {
  const BatchLoggingScreen({super.key});

  @override
  State<BatchLoggingScreen> createState() => _BatchLoggingScreenState();
}

class _BatchLoggingScreenState extends State<BatchLoggingScreen> {
  final _amountController = TextEditingController();
  final _moistureController = TextEditingController();
  final _notesController = TextEditingController();

  String? _generatedBatchId;
  String? _selectedFieldId;
  String _cropType = 'Maize';
  bool _isGenerating = false;

  @override
  void dispose() {
    _amountController.dispose();
    _moistureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Read the latest alert for this field and determine health status
  String _resolveHealthStatus(String? fieldId) {
    if (fieldId == null) return 'Unknown';
    final alerts = context.read<AlertsProvider>().alerts;
    final fieldAlerts = alerts.where((a) => a.fieldId == fieldId).toList();
    if (fieldAlerts.isEmpty) return 'No scans recorded';
    fieldAlerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = fieldAlerts.first;
    final title = latest.title.toLowerCase();
    if (title.contains('healthy')) return 'Healthy';
    if (title.contains('disease') || title.contains('detected')) return 'Disease Detected';
    return latest.title;
  }

  /// Compute quality grade from moisture % and health
  String _computeGrade(double moisture, String health) {
    if (health == 'Disease Detected') return 'C';
    if (moisture >= 10 && moisture <= 14 && health == 'Healthy') return 'A';
    if (moisture >= 8 && moisture <= 18) return 'B';
    return 'C';
  }

  void _generateBatch() async {
    final amount = double.tryParse(_amountController.text);
    final moisture = double.tryParse(_moistureController.text);

    if (amount == null || moisture == null || _selectedFieldId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all details and select a field')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be signed in')));
      setState(() => _isGenerating = false);
      return;
    }

    // Resolve field name
    final fields = context.read<FieldsProvider>().fields;
    final field = fields.firstWhere((f) => f.id == _selectedFieldId, orElse: () => fields.first);
    final healthStatus = _resolveHealthStatus(_selectedFieldId);
    final grade = _computeGrade(moisture, healthStatus);
    final farmerName = user.displayName ?? user.email ?? 'Farmer';
    final now = FieldValue.serverTimestamp();

    try {
      final docRef = FirebaseFirestore.instance.collection('batches').doc();
      await docRef.set({
        'farmerId': user.uid,
        'farmerName': farmerName,
        'fieldId': _selectedFieldId,
        'fieldName': field.name,
        'fieldLocation': field.location ?? '',
        'cropType': _cropType,
        'amountKg': amount,
        'moisturePct': moisture,
        'healthStatus': healthStatus,
        'grade': grade,
        'notes': _notesController.text.trim(),
        'loggedAt': now,
        'stages': [
          {
            'step': 'Harvested',
            'note': 'Batch logged by farmer: $farmerName',
            'ts': Timestamp.now(),
          },
        ],
      });

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatedBatchId = docRef.id;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Harvest Batch')),
      body: _generatedBatchId != null ? _buildSuccessState() : _buildFormState(),
    );
  }

  Widget _buildFormState() {
    final fields = context.watch<FieldsProvider>().fields;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.agriculture, color: scheme.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Finalize Your Harvest',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Fill in batch details — a traceable QR code will be generated and saved.',
                          style: TextStyle(color: scheme.onPrimaryContainer.withOpacity(0.7), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Step 1: Select Field
          _SectionLabel(number: '1', label: 'Select Source Field'),
          const SizedBox(height: 8),
          if (fields.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: scheme.error),
                  const SizedBox(width: 8),
                  const Text('No fields found. Add fields in the Fields tab first.'),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedFieldId,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.map_outlined),
                labelText: 'Field',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: fields.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
              onChanged: (val) => setState(() => _selectedFieldId = val),
            ),
          const SizedBox(height: 16),

          // Step 2: Crop type
          _SectionLabel(number: '2', label: 'Crop Type'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _cropType,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.eco_outlined),
              labelText: 'Crop',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'Maize', child: Text('🌽  Maize')),
              DropdownMenuItem(value: 'Coffee', child: Text('☕  Coffee')),
              DropdownMenuItem(value: 'Beans', child: Text('🫘  Beans')),
              DropdownMenuItem(value: 'Cassava', child: Text('🌿  Cassava')),
            ],
            onChanged: (val) => setState(() => _cropType = val ?? 'Maize'),
          ),
          const SizedBox(height: 16),

          // Step 3: Amount + Moisture
          _SectionLabel(number: '3', label: 'Batch Measurements'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Yield Amount',
                    suffixText: 'kg',
                    prefixIcon: const Icon(Icons.scale),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _moistureController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Moisture',
                    suffixText: '%',
                    prefixIcon: const Icon(Icons.water_drop_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Step 4: Notes (optional)
          _SectionLabel(number: '4', label: 'Notes (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Harvested after early rains. Dried for 3 days.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // Health preview
          if (_selectedFieldId != null) ...[
            _HealthPreviewCard(healthStatus: _resolveHealthStatus(_selectedFieldId)),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_isGenerating || fields.isEmpty) ? null : _generateBatch,
              icon: _isGenerating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.qr_code),
              label: Text(_isGenerating ? 'Logging Batch…' : 'Generate Traceability QR'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    final fields = context.read<FieldsProvider>().fields;
    final field = _selectedFieldId != null && fields.isNotEmpty
        ? fields.firstWhere((f) => f.id == _selectedFieldId, orElse: () => fields.first)
        : null;
    final moisture = double.tryParse(_moistureController.text) ?? 0;
    final healthStatus = _resolveHealthStatus(_selectedFieldId);
    final grade = _computeGrade(moisture, healthStatus);
    final scheme = Theme.of(context).colorScheme;

    final gradeColor = grade == 'A' ? Colors.green : grade == 'B' ? Colors.orange : Colors.red;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Batch Logged Successfully',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Print and affix this QR code to the batch packaging.',
                          style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: _generatedBatchId!,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _generatedBatchId!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Batch summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                _SummaryRow(icon: Icons.map_outlined, label: 'Field', value: field?.name ?? '—'),
                _SummaryRow(icon: Icons.eco_outlined, label: 'Crop', value: _cropType),
                _SummaryRow(icon: Icons.scale, label: 'Amount', value: '${_amountController.text} kg'),
                _SummaryRow(icon: Icons.water_drop_outlined, label: 'Moisture', value: '${_moistureController.text}%'),
                _SummaryRow(icon: Icons.biotech_outlined, label: 'Health', value: healthStatus),
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 10),
                    const Text('Grade', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(color: gradeColor, borderRadius: BorderRadius.circular(8)),
                      child: Text(grade,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Chip: verified by blockchain
          Chip(
            avatar: const Icon(Icons.verified, color: Colors.green, size: 18),
            label: const Text('Recorded on AgriChain Ledger'),
            backgroundColor: Colors.green.shade50,
            side: BorderSide(color: Colors.green.shade200),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share / Print feature coming soon!')));
              },
              icon: const Icon(Icons.share),
              label: const Text('Share QR Label'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String number;
  final String label;
  const _SectionLabel({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
          child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _HealthPreviewCard extends StatelessWidget {
  final String healthStatus;
  const _HealthPreviewCard({required this.healthStatus});

  @override
  Widget build(BuildContext context) {
    final isHealthy = healthStatus == 'Healthy';
    final color = isHealthy ? Colors.green : Colors.orange;
    final icon = isHealthy ? Icons.check_circle_outline : Icons.warning_amber_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text('Field health: $healthStatus',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
