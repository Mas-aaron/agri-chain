import 'package:flutter/material.dart';
import 'package:agri_chain/features/blockchain/services/web3_service.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final Web3Service _web3Service = Web3Service();
  final _formKey = GlobalKey<FormState>();
  final _recipientCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  
  bool _isSending = false;
  String? _txHash;
  String? _error;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final txHash = await _web3Service.sendTransaction(
        from: _web3Service.userAddress!,
        to: _recipientCtrl.text.trim(),
        amount: _amountCtrl.text,
      );

      setState(() {
        _txHash = txHash;
      });
    } catch (e) {
      setState(() {
        _error = 'Transaction failed: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _recipientCtrl,
                decoration: const InputDecoration(labelText: 'Recipient Address'),
                validator: (value) {
                  if (!Web3Service.isValidAddress(value ?? '')) {
                    return 'Invalid address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (ETH)'),
                validator: (value) {
                  if (value == null || double.tryParse(value) == null) {
                    return 'Invalid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSending ? null : _sendTransaction,
                child: Text(_isSending ? 'Sending...' : 'Send'),
              ),
              if (_txHash != null) ...[
                const SizedBox(height: 16),
                Text('Transaction: $_txHash'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
