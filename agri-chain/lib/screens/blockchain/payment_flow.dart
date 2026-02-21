import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:agri_chain/config/app_config.dart';
import 'package:agri_chain/services/contracts_api_service.dart';

/// Exchange rate for demo
const _ugxPerUsd = 3750.0;

/// Shows the payment bottom sheet / dialog for a contract.
/// Returns true if payment was successful.
Future<bool> showPaymentFlow(
  BuildContext context, {
  required YieldContractDto contract,
  VoidCallback? onNavigateToLedger,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PaymentSheet(
      contract: contract,
      onNavigateToLedger: onNavigateToLedger,
    ),
  );
  return result == true;
}

class _PaymentSheet extends StatefulWidget {
  final YieldContractDto contract;
  final VoidCallback? onNavigateToLedger;

  const _PaymentSheet({required this.contract, this.onNavigateToLedger});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  // State
  _PayStep _step = _PayStep.selectMethod;
  String _selectedMethod = 'momo_mtn';
  String _currency = 'UGX';
  bool _processing = false;
  String? _error;

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Payment result
  Map<String, dynamic>? _paymentResult;

  double get _amountUgx => widget.contract.total;
  double get _amountUsd => widget.contract.total / _ugxPerUsd;
  double get _displayAmount => _currency == 'UGX' ? _amountUgx : _amountUsd;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/payments');
      final body = {
        'contract_id': widget.contract.id,
        'amount': _displayAmount,
        'currency': _currency,
        'method': _selectedMethod,
        'payer_name': _nameController.text.trim(),
        'payer_phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'payer_email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      };

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode >= 400) {
        throw Exception('Payment failed (${resp.statusCode}): ${resp.body}');
      }

      final result = jsonDecode(resp.body) as Map<String, dynamic>;
      setState(() {
        _paymentResult = result;
        _step = _PayStep.success;
        _processing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPad),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (_step == _PayStep.selectMethod) _buildMethodStep(scheme),
              if (_step == _PayStep.confirm) _buildConfirmStep(scheme),
              if (_step == _PayStep.success) _buildSuccessStep(scheme),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1: Select Payment Method ──────────────────────────

  Widget _buildMethodStep(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.payment, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pay for Contract',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(widget.contract.id,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Contract summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.contract.crop} • ${widget.contract.quantityKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${widget.contract.farmerName}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_amountUgx.toStringAsFixed(0)} UGX',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    '≈ \$${_amountUsd.toStringAsFixed(2)} USD',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Currency toggle
        Text('Currency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Row(
          children: [
            _CurrencyChip(label: 'UGX 🇺🇬', selected: _currency == 'UGX', onTap: () => setState(() => _currency = 'UGX')),
            const SizedBox(width: 8),
            _CurrencyChip(label: 'USD 🇺🇸', selected: _currency == 'USD', onTap: () => setState(() => _currency = 'USD')),
          ],
        ),
        const SizedBox(height: 16),

        // Payment methods
        Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        _MethodTile(
          icon: Icons.phone_android,
          title: 'MTN Mobile Money',
          subtitle: 'Pay from your MTN MoMo wallet',
          color: const Color(0xFFFFCC00),
          selected: _selectedMethod == 'momo_mtn',
          onTap: () => setState(() => _selectedMethod = 'momo_mtn'),
        ),
        const SizedBox(height: 6),
        _MethodTile(
          icon: Icons.phone_android,
          title: 'Airtel Money',
          subtitle: 'Pay from your Airtel Money wallet',
          color: const Color(0xFFED1C24),
          selected: _selectedMethod == 'momo_airtel',
          onTap: () => setState(() => _selectedMethod = 'momo_airtel'),
        ),
        const SizedBox(height: 6),
        _MethodTile(
          icon: Icons.credit_card,
          title: 'Visa / Mastercard',
          subtitle: 'Pay with debit or credit card',
          color: const Color(0xFF1A1F71),
          selected: _selectedMethod == 'card',
          onTap: () => setState(() => _selectedMethod = 'card'),
        ),
        const SizedBox(height: 6),
        _MethodTile(
          icon: Icons.account_balance,
          title: 'Bank Transfer',
          subtitle: 'Direct bank transfer',
          color: Colors.teal,
          selected: _selectedMethod == 'bank',
          onTap: () => setState(() => _selectedMethod = 'bank'),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => setState(() => _step = _PayStep.confirm),
            icon: const Icon(Icons.arrow_forward),
            label: Text('Continue • ${_displayAmount.toStringAsFixed(_currency == "USD" ? 2 : 0)} $_currency'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Confirm & Pay ──────────────────────────────────

  Widget _buildConfirmStep(ColorScheme scheme) {
    final isMomo = _selectedMethod.startsWith('momo');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _step = _PayStep.selectMethod),
            ),
            const Text('Confirm Payment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 12),

        // Amount card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primary.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text('Total Amount',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${_displayAmount.toStringAsFixed(_currency == "USD" ? 2 : 0)} $_currency',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currency == 'UGX'
                    ? '≈ \$${_amountUsd.toStringAsFixed(2)} USD'
                    : '≈ ${_amountUgx.toStringAsFixed(0)} UGX',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Payer info
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Your Name *',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 10),

        if (isMomo) ...[
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: _selectedMethod == 'momo_mtn'
                  ? 'MTN Number (e.g. 0771234567)'
                  : 'Airtel Number (e.g. 0701234567)',
              prefixIcon: const Icon(Icons.phone),
            ),
          ),
        ] else ...[
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _processing ? null : _processPayment,
            icon: _processing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.lock),
            label: Text(_processing ? 'Processing...' : 'Pay Now'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green.shade700,
            ),
          ),
        ),

        const SizedBox(height: 10),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Secured by Hyperledger Fabric blockchain',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 3: Success ────────────────────────────────────────

  Widget _buildSuccessStep(ColorScheme scheme) {
    final r = _paymentResult ?? {};

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 56),
        ),
        const SizedBox(height: 16),
        const Text('Payment Successful!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          r['message']?.toString() ?? 'Your payment has been processed.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        // Receipt card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _ReceiptRow('Payment ID', r['payment_id']?.toString() ?? '-'),
              _ReceiptRow('Reference', r['reference']?.toString() ?? '-'),
              _ReceiptRow('Amount', '${r['amount'] ?? 0} ${r['currency'] ?? ''}'),
              _ReceiptRow('Method', r['method_label']?.toString() ?? '-'),
              _ReceiptRow('Status', r['status']?.toString() ?? '-'),
              _ReceiptRow('Contract', r['contract_id']?.toString() ?? '-'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context, true);
                  widget.onNavigateToLedger?.call();
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('View Ledger'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Helper Widgets ───────────────────────────────────────────

enum _PayStep { selectMethod, confirm, success }

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withOpacity(0.06) : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: scheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withOpacity(0.1) : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
