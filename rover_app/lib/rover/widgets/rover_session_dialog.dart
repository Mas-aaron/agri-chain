import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/rover_provider.dart';
import '../services/agrichain_backend_service.dart';

class RoverSessionDialog extends StatefulWidget {
  final String backendUrl;
  
  const RoverSessionDialog({
    super.key,
    required this.backendUrl,
  });

  @override
  State<RoverSessionDialog> createState() => _RoverSessionDialogState();
}

class _RoverSessionDialogState extends State<RoverSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _farmIdController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _farmIdController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = AgriChainBackendService(baseUrl: widget.backendUrl);
      final farmId = _farmIdController.text.trim();
      
      // We assume rover-01 for now, or it could be passed in
      final sessionId = await service.startSession(
        farmId: farmId,
        deviceId: 'rover-01',
      );

      if (!mounted) return;
      
      Provider.of<RoverProvider>(context, listen: false).setActiveSession(
        sessionId,
        farmId,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data collection session started successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start Data Session'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assign the rover\'s incoming sensor readings to a specific farm.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _farmIdController,
              decoration: const InputDecoration(
                labelText: 'Farm ID',
                hintText: 'e.g. farm_001',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.agriculture),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a Farm ID';
                }
                return null;
              },
              onFieldSubmitted: (_) => _startSession(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _startSession,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Start Session'),
        ),
      ],
    );
  }
}
