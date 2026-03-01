import 'package:flutter/material.dart';
import 'package:agri_chain/screens/traceability/qr_scanner_screen.dart';
import 'package:agri_chain/screens/traceability/batch_logging_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TraceabilityScreen extends StatefulWidget {
  const TraceabilityScreen({super.key});

  @override
  State<TraceabilityScreen> createState() => _TraceabilityScreenState();
}

class _TraceabilityScreenState extends State<TraceabilityScreen> {
  String? _scannedCode;
  bool _isLoadingBatch = false;
  Map<String, dynamic>? _batchData;

  void _scanQR() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (result != null) {
      setState(() {
        _scannedCode = result;
        _isLoadingBatch = true;
        _batchData = null;
      });
      _fetchBatch(result);
    }
  }

  Future<void> _fetchBatch(String batchId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('batches').doc(batchId).get();
      if (!mounted) return;
      
      if (doc.exists) {
        setState(() {
          _batchData = doc.data();
          _isLoadingBatch = false;
        });
      } else {
        setState(() => _isLoadingBatch = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code not found in ledger')));
      }
    } catch(e) {
      if (!mounted) return;
      setState(() => _isLoadingBatch = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fetch error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Traceability'),
      ),
      body: _scannedCode == null ? _buildEmptyState() : _buildTimeline(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanQR,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Product QR'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Trace Your Produce',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a QR code on an AgriChain-verified product to view its immutable journey from farm to table.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BatchLoggingScreen()),
                  );
                },
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Log New Harvest Batch'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    if (_isLoadingBatch) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_batchData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Could not load batch data.'),
            TextButton(
              onPressed: () => setState(() => _scannedCode = null),
              child: const Text('Go Back'),
            )
          ],
        ),
      );
    }

    final amount = _batchData?['amount']?.toString() ?? 'Unknown';
    final moisture = _batchData?['moisture']?.toString() ?? 'Unknown';
    final timestamp = _batchData?['createdAt'] as Timestamp?;
    
    final harvestDateStr = timestamp != null 
        ? DateFormat.yMMMd().format(timestamp.toDate()) 
        : 'Unknown Date';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scanned Batch Info', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                _scannedCode!,
                style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Chip(
                label: const Text('Verified by AgriChain Blockchain'),
                backgroundColor: Colors.white.withOpacity(0.5),
                side: BorderSide.none,
                avatar: const Icon(Icons.verified, color: Colors.green, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Product Journey',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        _TimelineStep(
          isActive: true,
          isFirst: true,
          icon: Icons.grass,
          title: 'Planting & Growth',
          time: 'Previous Season',
          description: 'Planted in registered Field. Monitored by edge AI models ensuring disease-free growth period.',
        ),
        _TimelineStep(
          isActive: true,
          icon: Icons.agriculture,
          title: 'Harvesting',
          time: harvestDateStr,
          description: 'Harvested $amount kg under optimal moisture levels ($moisture%). Yield matched AI predictions.',
        ),
        _TimelineStep(
          isActive: true,
          icon: Icons.precision_manufacturing,
          title: 'Processing',
          time: harvestDateStr,
          description: 'Sorted, dried, and packed at Central Mill Hub. Quality grade: Premium Grade 1.',
        ),
        _TimelineStep(
          isActive: false,
          isLast: true,
          icon: Icons.local_shipping,
          title: 'Transport / Retail',
          time: 'Pending',
          description: 'Currently en route to local distributors or awaiting pickup.',
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final bool isActive;
  final bool isFirst;
  final bool isLast;
  final IconData icon;
  final String title;
  final String time;
  final String description;

  const _TimelineStep({
    required this.isActive,
    this.isFirst = false,
    this.isLast = false,
    required this.icon,
    required this.title,
    required this.time,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isActive ? scheme.primary : Colors.grey.shade400;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 16,
                  color: isFirst ? Colors.transparent : color,
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? scheme.primaryContainer : Colors.grey.shade200,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(time, style: TextStyle(fontSize: 12, color: isActive ? scheme.primary : Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(description, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
