import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:agri_chain/config/app_config.dart';

// ── Loan Model ───────────────────────────────────────────────

class LoanRecord {
  final String loanId;
  final String tokenId;
  final String assetId;
  final String farmerId;
  final double loanAmount;
  final String currency;
  final double collateralValue;
  final double ltvPercent;
  final int repaymentMonths;
  final double interestRate;
  final double monthlyPayment;
  final String lender;
  final String status;
  final String? cropType;
  final String? qualityGrade;
  final String createdAt;

  const LoanRecord({
    required this.loanId,
    required this.tokenId,
    required this.assetId,
    required this.farmerId,
    required this.loanAmount,
    required this.currency,
    required this.collateralValue,
    required this.ltvPercent,
    required this.repaymentMonths,
    required this.interestRate,
    required this.monthlyPayment,
    required this.lender,
    required this.status,
    this.cropType,
    this.qualityGrade,
    required this.createdAt,
  });

  factory LoanRecord.fromJson(Map<String, dynamic> j) {
    return LoanRecord(
      loanId: (j['loan_id'] ?? '').toString(),
      tokenId: (j['token_id'] ?? '').toString(),
      assetId: (j['asset_id'] ?? '').toString(),
      farmerId: (j['farmer_id'] ?? '').toString(),
      loanAmount: _d(j['loan_amount']),
      currency: (j['currency'] ?? 'USD').toString(),
      collateralValue: _d(j['collateral_value']),
      ltvPercent: _d(j['ltv_percent']),
      repaymentMonths: (j['repayment_months'] is num)
          ? (j['repayment_months'] as num).toInt()
          : 12,
      interestRate: _d(j['interest_rate']),
      monthlyPayment: _d(j['monthly_payment']),
      lender: (j['lender'] ?? '—').toString(),
      status: (j['status'] ?? 'PENDING').toString(),
      cropType: j['crop_type']?.toString(),
      qualityGrade: j['quality_grade']?.toString(),
      createdAt: (j['created_at'] ?? '').toString(),
    );
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'REPAID':
        return Colors.blue;
      case 'DEFAULTED':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.hourglass_empty_rounded;
      case 'APPROVED':
        return Icons.check_circle_rounded;
      case 'REJECTED':
        return Icons.cancel_rounded;
      case 'REPAID':
        return Icons.task_alt_rounded;
      case 'DEFAULTED':
        return Icons.warning_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}

// ── Screen ───────────────────────────────────────────────────

class LoansScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMarketplace;

  const LoansScreen({super.key, this.onNavigateToMarketplace});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  late Future<List<LoanRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchLoans();
  }

  Future<List<LoanRecord>> _fetchLoans() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/loans');
    final resp = await http
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode >= 400) {
      throw Exception('Failed to load loans (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return [];
    return decoded
        .map((e) => LoanRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _reload() => setState(() => _future = _fetchLoans());

  // ── Summary stats ─────────────────────────────────────────

  Widget _buildSummaryBanner(List<LoanRecord> loans, ColorScheme scheme) {
    final total = loans.fold<double>(0, (s, l) => s + l.loanAmount);
    final pending = loans.where((l) => l.status.toUpperCase() == 'PENDING').length;
    final approved = loans.where((l) => l.status.toUpperCase() == 'APPROVED').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _BannerStat(
            label: 'Total Borrowed',
            value: '\$${total.toStringAsFixed(0)}',
          ),
          const SizedBox(width: 24),
          _BannerStat(label: 'Applications', value: '${loans.length}'),
          const SizedBox(width: 24),
          _BannerStat(label: 'Pending', value: '$pending'),
          const SizedBox(width: 24),
          _BannerStat(label: 'Approved', value: '$approved'),
        ],
      ),
    );
  }

  // ── Loan card ────────────────────────────────────────────

  Widget _buildLoanCard(LoanRecord loan, ColorScheme scheme) {
    final dateStr = loan.createdAt.length >= 10
        ? loan.createdAt.substring(0, 10)
        : loan.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withOpacity(0.07),
                  scheme.primary.withOpacity(0.01),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_balance_outlined,
                      color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.loanId,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${loan.lender}  •  ${loan.cropType ?? '—'}  •  Grade ${loan.qualityGrade ?? '—'}',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: loan.statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(loan.statusIcon,
                          color: loan.statusColor, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        loan.status,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: loan.statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Details grid ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.attach_money,
                        label: 'Loan Amount',
                        value:
                            '\$${loan.loanAmount.toStringAsFixed(2)} ${loan.currency}',
                        valueColor: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.lock_outlined,
                        label: 'Collateral',
                        value:
                            '\$${loan.collateralValue.toStringAsFixed(0)} (${loan.ltvPercent.toInt()}% LTV)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.percent_rounded,
                        label: 'Interest Rate',
                        value: '${loan.interestRate.toStringAsFixed(1)}% p.a.',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.calendar_month_outlined,
                        label: 'Term',
                        value: '${loan.repaymentMonths} months',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.payments_outlined,
                        label: 'Monthly Payment',
                        value:
                            '\$${loan.monthlyPayment.toStringAsFixed(2)}',
                        valueColor: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.token_outlined,
                        label: 'Collateral Token',
                        value: loan.tokenId,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Applied: $dateStr',
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────

  Widget _buildEmpty(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_outlined,
                  size: 56, color: scheme.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'No Loan Applications',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface),
            ),
            const SizedBox(height: 10),
            Text(
              'Apply for a loan by pledging a yield token as\ncollateral from the Token Marketplace.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: widget.onNavigateToMarketplace,
              icon: const Icon(Icons.token_outlined),
              label: const Text('Go to Token Marketplace'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loans'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reload,
              tooltip: 'Refresh'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onNavigateToMarketplace,
        icon: const Icon(Icons.add),
        label: const Text('Apply for Loan'),
        tooltip: 'Go to Token Marketplace to apply',
      ),
      body: FutureBuilder<List<LoanRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 12),
                  Text('Error: ${snap.error}',
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final loans = snap.data ?? [];
          if (loans.isEmpty) return _buildEmpty(scheme);

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _buildSummaryBanner(loans, scheme),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(
                  '${loans.length} Application${loans.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant),
                ),
              ),
              ...loans.map((l) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildLoanCard(l, scheme),
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ── Helper Widgets ───────────────────────────────────────────

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  const _BannerStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.75), fontSize: 11)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.primary.withOpacity(0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? scheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
