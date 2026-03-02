import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BatchLoggingScreen extends StatefulWidget {
  const BatchLoggingScreen({super.key});

  @override
  State<BatchLoggingScreen> createState() => _BatchLoggingScreenState();
}

class _BatchLoggingScreenState extends State<BatchLoggingScreen> {
  final _amountController = TextEditingController();
  final _moistureController = TextEditingController();
  
  String? _generatedQrData;
  bool _isGenerating = false;

  void _generateBatch() async {
    final amount = _amountController.text;
    final moisture = _moistureController.text;

    if (amount.isEmpty || moisture.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all details')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be signed in')));
      setState(() => _isGenerating = false);
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('batches').doc();
      await docRef.set({
        'amount': double.tryParse(amount) ?? 0.0,
        'moisture': double.tryParse(moisture) ?? 0.0,
        'farmerId': user.uid,
        'fieldId': '1', // Hardcoded field for now
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatedQrData = docRef.id;
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
      appBar: AppBar(
        title: const Text('Log Harvest Batch'),
      ),
      body: _generatedQrData != null ? _buildSuccessState() : _buildFormState(),
    );
  }

  Widget _buildFormState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finalize your harvest',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the details of the processed batch. A unique QR code will be generated and logged to the immutable ledger.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Total Yield Amount',
              suffixText: 'kg',
              prefixIcon: Icon(Icons.scale),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _moistureController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Measured Moisture Content',
              suffixText: '%',
              prefixIcon: Icon(Icons.water_drop_outlined),
            ),
          ),
          const SizedBox(height: 16),
          // For a real app, you would select the specific field this came from
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Source Field', prefixIcon: Icon(Icons.map_outlined)),
            items: const [
              DropdownMenuItem(value: '1', child: Text('Field A - Premium Maize')),
            ],
            onChanged: (val) {},
            value: '1',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isGenerating ? null : _generateBatch,
              icon: _isGenerating 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.qr_code),
              label: Text(_isGenerating ? 'Logging Batch...' : 'Generate Traceability QR'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: 60, color: Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Batch Logged Successfully',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Print this QR code and affix it to the batch packaging.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _generatedQrData!,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _generatedQrData!,
              style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace', fontSize: 16),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // In a real app, this would trigger a print job or share as an image
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading label...')));
                },
                icon: const Icon(Icons.print),
                label: const Text('Print Label'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Dashboard'),
            )
          ],
        ),
      ),
    );
  }
}
