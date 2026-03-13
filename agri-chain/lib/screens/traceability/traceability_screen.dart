import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agri_chain/screens/traceability/qr_scanner_screen.dart';
import 'package:agri_chain/screens/traceability/batch_logging_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─── Stage definitions (order matters) ───────────────────────────────────────
const _stageOrder = ['Harvested', 'Processed', 'In Transit', 'Delivered'];
const _stageIcons = <String, IconData>{
  'Harvested': Icons.agriculture,
  'Processed': Icons.precision_manufacturing,
  'In Transit': Icons.local_shipping,
  'Delivered': Icons.storefront,
};
const _stageDescriptions = <String, String>{
  'Harvested': 'Crop harvested from the registered field and logged to the AgriChain ledger.',
  'Processed': 'Sorted, dried, and packed at the processing hub.',
  'In Transit': 'Batch dispatched. En route to distributor or retail point.',
  'Delivered': 'Product arrived at its final destination and confirmed by receiver.',
};

class TraceabilityScreen extends StatefulWidget {
  const TraceabilityScreen({super.key});

  @override
  State<TraceabilityScreen> createState() => _TraceabilityScreenState();
}

class _TraceabilityScreenState extends State<TraceabilityScreen> {
  String? _scannedBatchId;
  bool _isLoading = false;
  Map<String, dynamic>? _batchData;

  // ── QR scan ────────────────────────────────────────────────────────────────
  void _scanQR() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (result != null) _loadBatch(result);
  }

  // ── Manual entry ───────────────────────────────────────────────────────────
  void _enterManually() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Batch ID'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Paste batch ID here…'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (ctrl.text.isNotEmpty) _loadBatch(ctrl.text.trim());
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  // ── Fetch batch ────────────────────────────────────────────────────────────
  Future<void> _loadBatch(String batchId) async {
    setState(() {
      _scannedBatchId = batchId;
      _isLoading = true;
      _batchData = null;
    });
    try {
      final doc = await FirebaseFirestore.instance.collection('batches').doc(batchId).get();
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          _batchData = {'id': doc.id, ...doc.data()!};
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Batch not found. Check the QR code and try again.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error fetching batch: $e')));
    }
  }

  // ── Add next stage (farmer only) ───────────────────────────────────────────
  Future<void> _addNextStage() async {
    if (_batchData == null || _scannedBatchId == null) return;

    final stages = (_batchData!['stages'] as List? ?? [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    final completedSteps = stages.map((s) => s['step'] as String).toSet();
    final nextStep = _stageOrder.firstWhere(
      (s) => !completedSteps.contains(s),
      orElse: () => '',
    );
    if (nextStep.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('All stages are already completed.')));
      return;
    }

    // Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Mark as: $nextStep?'),
        content: Text(_stageDescriptions[nextStep] ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;

    final newStage = {
      'step': nextStep,
      'note': 'Confirmed by ${FirebaseAuth.instance.currentUser?.displayName ?? 'user'}',
      'ts': Timestamp.now(),
    };

    await FirebaseFirestore.instance.collection('batches').doc(_scannedBatchId).update({
      'stages': FieldValue.arrayUnion([newStage]),
    });

    // Reload
    _loadBatch(_scannedBatchId!);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isBatchOwner = _batchData != null && _batchData!['farmerId'] == uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Traceability'),
        actions: [
          if (_scannedBatchId != null)
            IconButton(
              tooltip: 'Scan another',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _scanQR,
            ),
        ],
      ),
      body: _body(),
      floatingActionButton: _scannedBatchId == null
          ? null
          : isBatchOwner
              ? FloatingActionButton.extended(
                  onPressed: _addNextStage,
                  icon: const Icon(Icons.update),
                  label: const Text('Update Stage'),
                )
              : null,
    );
  }

  Widget _body() {
    if (_scannedBatchId == null) return _buildLanding();
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_batchData == null) return _buildNotFound();
    return _buildVerification();
  }

  // ── Landing screen ─────────────────────────────────────────────────────────
  Widget _buildLanding() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.qr_code_2, size: 52, color: scheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Verify Your Produce',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan the QR code on an AgriChain product to view its complete farm-to-fork journey — field, health status, harvest details, and delivery chain.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _scanQR,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Product QR Code'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _enterManually,
                icon: const Icon(Icons.keyboard_outlined),
                label: const Text('Enter Batch ID Manually'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 16),
            Text('Are you a farmer?',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BatchLoggingScreen()),
              ),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Log a New Harvest Batch'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Not found ──────────────────────────────────────────────────────────────
  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('Batch not found.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text('This QR code was not found in the AgriChain system.',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => setState(() => _scannedBatchId = null),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ── Verification screen ────────────────────────────────────────────────────
  Widget _buildVerification() {
    final data = _batchData!;
    final scheme = Theme.of(context).colorScheme;

    final stages = (data['stages'] as List? ?? [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    final completedSteps = stages.map((s) => s['step'] as String).toSet();
    final grade = data['grade'] as String? ?? '—';
    final gradeColor = grade == 'A' ? Colors.green : grade == 'B' ? Colors.orange : Colors.red;
    final health = data['healthStatus'] as String? ?? '—';
    final isHealthy = health == 'Healthy';
    final loggedAt = data['loggedAt'] as Timestamp?;
    final loggedDateStr = loggedAt != null
        ? DateFormat('d MMM yyyy, h:mm a').format(loggedAt.toDate().toLocal())
        : '—';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Verified header ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 22),
                  const SizedBox(width: 8),
                  Text('AgriChain Verified',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration:
                        BoxDecoration(color: gradeColor, borderRadius: BorderRadius.circular(8)),
                    child: Text('Grade $grade',
                        style:
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _scannedBatchId!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copy batch ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _scannedBatchId!));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Batch ID copied!')));
                    },
                  ),
                ],
              ),
              Text('Logged: $loggedDateStr',
                  style: TextStyle(color: scheme.onPrimaryContainer.withOpacity(0.6), fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Farm info ──
        _InfoSection(
          title: 'Farm & Field',
          icon: Icons.grass,
          children: [
            _InfoRow('Farmer', data['farmerName'] ?? '—'),
            _InfoRow('Field', data['fieldName'] ?? '—'),
            if ((data['fieldLocation'] as String?)?.isNotEmpty ?? false)
              _InfoRow('Location', data['fieldLocation'] as String),
            _InfoRow('Crop', data['cropType'] ?? '—'),
          ],
        ),
        const SizedBox(height: 12),

        // ── Health & Batch ──
        _InfoSection(
          title: 'Batch Details',
          icon: Icons.inventory_2_outlined,
          children: [
            _InfoRow('Yield', '${data['amountKg']} kg'),
            _InfoRow('Moisture', '${data['moisturePct']}%'),
            Row(
              children: [
                const Text('Health Status',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                Icon(
                  isHealthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  color: isHealthy ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(health,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isHealthy ? Colors.green : Colors.orange)),
              ],
            ),
            if ((data['notes'] as String?)?.isNotEmpty ?? false)
              _InfoRow('Notes', data['notes'] as String),
          ],
        ),
        const SizedBox(height: 16),

        // ── Journey timeline ──
        Text('Product Journey',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        for (int i = 0; i < _stageOrder.length; i++) ...[
          _buildTimelineStep(
            context: context,
            step: _stageOrder[i],
            isCompleted: completedSteps.contains(_stageOrder[i]),
            isFirst: i == 0,
            isLast: i == _stageOrder.length - 1,
            stages: stages,
          ),
        ],

        const SizedBox(height: 24),

        // ── Scan another ──
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              _scannedBatchId = null;
              _batchData = null;
            }),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another Product'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTimelineStep({
    required BuildContext context,
    required String step,
    required bool isCompleted,
    required bool isFirst,
    required bool isLast,
    required List<Map<String, dynamic>> stages,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = isCompleted ? scheme.primary : Colors.grey.shade300;
    final stageEntry = stages.firstWhere((s) => s['step'] == step, orElse: () => {});
    final ts = stageEntry['ts'] as Timestamp?;
    final timeStr = ts != null ? DateFormat('d MMM yyyy, h:mm a').format(ts.toDate().toLocal()) : null;
    final note = stageEntry['note'] as String?;
    final description = _stageDescriptions[step] ?? '';
    final icon = _stageIcons[step] ?? Icons.circle;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Line + dot
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(width: 2, height: 16, color: isFirst ? Colors.transparent : color),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted ? scheme.primaryContainer : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 17, color: isCompleted ? scheme.primary : Colors.grey.shade400),
                ),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : color)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(step,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isCompleted ? null : Colors.grey.shade400)),
                      const Spacer(),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Done ✓',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700)),
                        )
                      else
                        Text('Pending',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(isCompleted ? (note ?? description) : description,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                  if (timeStr != null) ...[
                    const SizedBox(height: 4),
                    Text(timeStr,
                        style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _InfoSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
