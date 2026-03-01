import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:agri_chain/config/app_config.dart';
import 'package:agri_chain/screens/blockchain/token_marketplace_screen.dart'
    show TokenAsset;

// ── Lender data ─────────────────────────────────────────────

class _Lender {
  final String name;
  final String logo; // emoji for now
  final String tagline;
  final double baseRate; // annual interest %

  const _Lender({
    required this.name,
    required this.logo,
    required this.tagline,
    required this.baseRate,
  });
}

const _lenders = [
  _Lender(
      name: 'AgriFinance Ltd',
      logo: '🌱',
      tagline: 'Specialised agricultural lending',
      baseRate: 14.0),
  _Lender(
      name: 'Centenary Bank',
      logo: '🏦',
      tagline: 'Uganda\'s leading rural bank',
      baseRate: 17.5),
  _Lender(
      name: 'DFCU Bank',
      logo: '💼',
      tagline: 'Development finance for farmers',
      baseRate: 16.0),
  _Lender(
      name: 'Equity Bank',
      logo: '🤝',
      tagline: 'Pan-African agri lending',
      baseRate: 15.5),
];

// ── Screen ───────────────────────────────────────────────────

class LoanApplicationScreen extends StatefulWidget {
  final TokenAsset token;

  const LoanApplicationScreen({super.key, required this.token});

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  // Defaults
  double _ltvPercent = 60.0; // 60% of token value
  int _repaymentMonths = 12;
  int _selectedLenderIndex = 0;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;

  double get _collateralValue => widget.token.currentValue;
  double get _loanAmount => (_ltvPercent / 100) * _collateralValue;
  _Lender get _lender => _lenders[_selectedLenderIndex];

  double get _interestRate {
    // Better quality grade → lower rate
    final gradeDiscount = switch (widget.token.qualityGrade) {
      'A+' => 2.0,
      'A' => 1.5,
      'B+' => 0.5,
      _ => 0.0,
    };
    return _lender.baseRate - gradeDiscount;
  }

  double get _monthlyPayment {
    final r = _interestRate / 100 / 12;
    final n = _repaymentMonths;
    final p = _loanAmount;
    if (r == 0) return p / n;
    return p * r * (1 + r).pow(n) / ((1 + r).pow(n) - 1);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final resp = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/loans'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token_id': widget.token.tokenId,
              'asset_id': widget.token.assetId,
              'farmer_id': widget.token.farmerId,
              'loan_amount': _loanAmount,
              'currency': 'USD',
              'collateral_value': _collateralValue,
              'ltv_percent': _ltvPercent,
              'repayment_months': _repaymentMonths,
              'interest_rate': _interestRate,
              'monthly_payment': _monthlyPayment,
              'lender': _lender.name,
              'crop_type': widget.token.cropType,
              'quality_grade': widget.token.qualityGrade,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode >= 400) {
        final body = jsonDecode(resp.body);
        throw Exception(
            (body['detail'] ?? body['message'] ?? 'Submission failed').toString());
      }

      setState(() {
        _result = jsonDecode(resp.body) as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Loan')),
      body: _result != null
          ? _buildSuccessScreen(scheme)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCollateralCard(scheme),
                  const SizedBox(height: 20),
                  _buildLoanConfig(scheme),
                  const SizedBox(height: 20),
                  _buildLenderSelector(scheme),
                  const SizedBox(height: 20),
                  _buildSummaryCard(scheme),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorCard(scheme),
                  ],
                  const SizedBox(height: 20),
                  _buildSubmitButton(scheme),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Your yield token will be held as collateral until the loan is repaid.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCollateralCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.token, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.token.tokenId,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  Text(
                    '${widget.token.cropType} • ${widget.token.predictedYield.toStringAsFixed(0)} kg • Grade ${widget.token.qualityGrade}',
                    style:
                        TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _WhiteStat(label: 'Token Value',
                value: '\$${_collateralValue.toStringAsFixed(0)}'),
            const SizedBox(width: 16),
            _WhiteStat(label: 'Quality Grade', value: widget.token.qualityGrade),
            const SizedBox(width: 16),
            _WhiteStat(
                label: 'Confidence',
                value:
                    '${(widget.token.confidence * 100).toStringAsFixed(0)}%'),
          ]),
        ],
      ),
    );
  }

  Widget _buildLoanConfig(ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loan Configuration',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            // LTV slider
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Loan Amount',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant)),
              Text(
                '\$${_loanAmount.toStringAsFixed(0)} (${_ltvPercent.toInt()}% of value)',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: scheme.primary),
              ),
            ]),
            Slider(
              value: _ltvPercent,
              min: 30,
              max: 80,
              divisions: 10,
              label: '${_ltvPercent.toInt()}%',
              onChanged: (v) => setState(() => _ltvPercent = v),
            ),
            Text(
              'Borrow between 30%–80% of your token\'s predicted value',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Repayment period
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Repayment Period',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant)),
              Text('$_repaymentMonths months',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: scheme.primary)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [3, 6, 12, 24].map((m) {
                final selected = m == _repaymentMonths;
                return ChoiceChip(
                  label: Text('${m}mo'),
                  selected: selected,
                  onSelected: (_) => setState(() => _repaymentMonths = m),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLenderSelector(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Select Lender',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: scheme.onSurface)),
        ),
        ..._lenders.asMap().entries.map((entry) {
          final i = entry.key;
          final l = entry.value;
          final selected = i == _selectedLenderIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedLenderIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withOpacity(0.07)
                    : scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : scheme.outlineVariant.withOpacity(0.4),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Text(l.logo, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(l.tagline,
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${(l.baseRate - (switch (widget.token.qualityGrade) { 'A+' => 2.0, 'A' => 1.5, 'B+' => 0.5, _ => 0.0 })).toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        fontSize: 16),
                  ),
                  Text('p.a.',
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant)),
                ]),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: scheme.primary, size: 20),
                ],
              ]),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loan Summary',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: scheme.primary)),
          const SizedBox(height: 12),
          _SummaryRow('Loan Amount',
              '\$${_loanAmount.toStringAsFixed(2)} USD'),
          _SummaryRow('Interest Rate', '${_interestRate.toStringAsFixed(1)}% p.a.'),
          _SummaryRow('Repayment', '$_repaymentMonths months'),
          _SummaryRow(
              'Monthly Payment', '\$${_monthlyPayment.toStringAsFixed(2)} USD'),
          _SummaryRow('Lender', _lender.name),
          const Divider(height: 20),
          _SummaryRow(
            'Collateral (locked until repaid)',
            widget.token.tokenId,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: Colors.red.shade700),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_error!,
                style: TextStyle(color: Colors.red.shade800, fontSize: 13))),
      ]),
    );
  }

  Widget _buildSubmitButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_outlined),
        label: Text(_submitting ? 'Submitting…' : 'Submit Loan Application'),
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    );
  }

  Widget _buildSuccessScreen(ColorScheme scheme) {
    final r = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 64),
          ),
          const SizedBox(height: 20),
          Text('Application Submitted!',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            r['message']?.toString() ?? 'Your loan application has been submitted.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(children: [
              _SummaryRow('Loan ID', r['loan_id']?.toString() ?? '-'),
              _SummaryRow('Amount',
                  '\$${(r['loan_amount'] as num?)?.toStringAsFixed(2) ?? '-'} USD'),
              _SummaryRow('Lender', r['lender']?.toString() ?? '-'),
              _SummaryRow(
                  'Monthly', '\$${(r['monthly_payment'] as num?)?.toStringAsFixed(2) ?? '-'}'),
              _SummaryRow('Status', r['status']?.toString() ?? 'PENDING'),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Marketplace'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The lender will review your application and contact you within 24–48 hours.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ───────────────────────────────────────────

class _WhiteStat extends StatelessWidget {
  final String label;
  final String value;
  const _WhiteStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.7), fontSize: 10)),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
    ]);
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _SummaryRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight ? scheme.primary : scheme.onSurface,
            ),
          ),
        ),
      ]),
    );
  }
}

// Dart extension for power on double (used in monthly payment calc)
extension _DoubleExt on double {
  double pow(int n) {
    double result = 1;
    for (var i = 0; i < n; i++) {
      result *= this;
    }
    return result;
  }
}
