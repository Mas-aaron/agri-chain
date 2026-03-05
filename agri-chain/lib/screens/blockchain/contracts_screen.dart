import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'package:agri_chain/services/contracts_api_service.dart';
import 'package:agri_chain/widgets/modern_ui.dart';
import 'package:agri_chain/config/app_config.dart';
import 'package:agri_chain/screens/blockchain/payment_flow.dart';
import 'package:url_launcher/url_launcher.dart';

class YieldContract {
  final String id;
  final String crop;
  final double quantityKg;
  final double unitPrice;
  final String currency;
  final String status;
  final DateTime createdAt;

  const YieldContract({
    required this.id,
    required this.crop,
    required this.quantityKg,
    required this.unitPrice,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  double get total => quantityKg * unitPrice;
}

class ContractsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToLedger;

  const ContractsScreen({super.key, this.onNavigateToLedger});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  late final ContractsApiService _api;
  late Future<List<YieldContractDto>> _future;

  @override
  void initState() {
    super.initState();
    _api = ContractsApiService.fromBaseUrl(AppConfig.apiBaseUrl);
    _reload();
  }

  void _reload() {
    setState(() {
      // Show all contracts — farmerName is a blockchain/token ID, not a Firebase UID,
      // so UID-based filtering would hide everything. Backend should handle auth scope.
      _future = _api.listContracts();
    });
  }

  Color _statusColor(BuildContext context, String status) {
    final s = status.toLowerCase();
    if (s.contains('listed')) return Theme.of(context).colorScheme.primary;
    if (s.contains('purchased')) return Colors.orange;
    if (s.contains('delivered')) return Colors.blue;
    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contracts'),
        actions: [
          IconButton(
            tooltip: 'Create contract (Farmer demo)',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showCreateContractDialog(),
          ),
        ],
      ),
      body: FutureBuilder<List<YieldContractDto>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ImageHeroCard(
                  assetPath: 'assets/images/logo.png',
                  title: 'Future harvest contracts',
                  subtitle: 'List your predicted harvest or purchase securely.',
                ),
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ImageHeroCard(
                  assetPath: 'assets/images/logo.png',
                  title: 'Future harvest contracts',
                  subtitle: 'List your predicted harvest or purchase securely.',
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Could not load contracts',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text('${snapshot.error}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ImageHeroCard(
                  assetPath: 'assets/images/logo.png',
                  title: 'Future harvest contracts',
                  subtitle: 'List your predicted harvest or purchase securely.',
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No contracts yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap + to create your first harvest listing. Buyers will see it here.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return ImageHeroCard(
                    assetPath: 'assets/images/logo.png',
                    title: 'Future harvest contracts',
                    subtitle: 'List your predicted harvest or purchase securely.',
                  );
                }

                final c = items[i - 1];
                final color = _statusColor(context, c.status);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.id,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                c.status,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _kv(context, 'Crop', c.crop)),
                            Expanded(child: _kv(context, 'Qty', '${c.quantityKg.toStringAsFixed(0)} kg')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _kv(context, 'Unit price', '${c.unitPrice.toStringAsFixed(0)} ${c.currency}')),
                            Expanded(child: _kv(context, 'Total', '${c.total.toStringAsFixed(0)} ${c.currency}')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (c.status.toUpperCase() == 'LISTED')
                              FilledButton.icon(
                                onPressed: () async {
                                  final paid = await showPaymentFlow(
                                    context,
                                    contract: c,
                                    onNavigateToLedger: widget.onNavigateToLedger,
                                  );
                                  if (paid && context.mounted) _reload();
                                },
                                icon: const Icon(Icons.payment, size: 18),
                                label: const Text('Purchase & Pay'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                ),
                              ),
                            if (c.status.toUpperCase() == 'PURCHASED') ...([
                              OutlinedButton.icon(
                                onPressed: () => _showDeliverDialog(c),
                                icon: const Icon(Icons.local_shipping_outlined),
                                label: const Text('Mark Delivered'),
                              ),
                              // Loan application — only available after contract is PURCHASED
                              FilledButton.icon(
                                onPressed: () => _showLoanDialog(c),
                                icon: const Icon(Icons.account_balance, size: 18),
                                label: const Text('Apply for Loan'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.purple.shade700,
                                ),
                              ),
                            ]),
                            // Blockchain explorer link
                            OutlinedButton.icon(
                              onPressed: () async {
                                final url = Uri.parse(
                                    '${AppConfig.explorerBaseUrl}/contracts/${c.id}');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url,
                                      mode: LaunchMode.externalApplication);
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Could not open explorer')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Explorer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(v, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _showCreateContractDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Not signed in')));
      }
      return;
    }

    final cropCtrl = TextEditingController(text: 'Maize');
    final qtyCtrl = TextEditingController(text: '1000');
    final priceCtrl = TextEditingController(text: '1200');
    final phoneCtrl = TextEditingController();
    bool submitting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.add_circle_outline, color: scheme.primary),
            const SizedBox(width: 8),
            const Text('Create Contract'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cropCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Crop',
                    prefixIcon: Icon(Icons.grass),
                    hintText: 'e.g. Maize, Coffee',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity (kg)',
                    prefixIcon: Icon(Icons.scale),
                    hintText: 'e.g. 1000',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price (UGX)',
                    prefixIcon: Icon(Icons.payments_outlined),
                    hintText: 'e.g. 1200',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (for SMS alerts)',
                    prefixIcon: Icon(Icons.phone),
                    hintText: 'e.g. +256700123456',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You will receive SMS notifications when someone purchases this contract.',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: submitting
                  ? null
                  : () async {
                      setS(() => submitting = true);
                      try {
                        final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                        final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                        if (qty <= 0 || price <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Enter valid quantity and price')),
                          );
                          setS(() => submitting = false);
                          return;
                        }
                        await _api.createContract(
                          ContractCreateRequest(
                            crop: cropCtrl.text.trim().isEmpty ? 'Maize' : cropCtrl.text.trim(),
                            quantityKg: qty,
                            unitPrice: price,
                            currency: 'UGX',
                            farmerName: user.uid,
                            farmerPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Create failed: $e')),
                          );
                        }
                      } finally {
                        setS(() => submitting = false);
                      }
                    },
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(submitting ? 'Creating…' : 'Create Contract'),
            ),
          ],
        );
      }),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contract created successfully!')),
      );
      _reload();
    }
  }

  Future<void> _showDeliverDialog(YieldContractDto contract) async {
    final actorCtrl = TextEditingController(text: 'Logistics');
    final refCtrl = TextEditingController(
        text: 'DEL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.local_shipping_outlined, color: scheme.primary),
            const SizedBox(width: 8),
            const Text('Mark As Delivered'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: scheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${contract.crop} — ${contract.quantityKg.toStringAsFixed(0)} kg',
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: actorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Delivered by',
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'e.g. Logistics, ABC Transport',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Delivery Reference',
                  prefixIcon: Icon(Icons.tag),
                  hintText: 'e.g. DEL-001234',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Confirm Delivery'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _api.deliverContract(
        contract.id,
        ContractDeliverRequest(
          actor: actorCtrl.text.trim().isEmpty ? 'Logistics' : actorCtrl.text.trim(),
          ref: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Contract marked as delivered!'),
          backgroundColor: Colors.green.shade700,
          action: widget.onNavigateToLedger != null
              ? SnackBarAction(
                  label: 'View Ledger',
                  textColor: Colors.white,
                  onPressed: widget.onNavigateToLedger!,
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deliver failed: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  // ── Loan Application ─────────────────────────────────────────

  Future<void> _showLoanDialog(YieldContractDto contract) async {
    final collateralValue = contract.total;
    double ltvPercent = 60.0;
    int repaymentMonths = 12;
    int selectedLender = 0;

    const lenders = [
      ('AgriFinance Ltd', 14.0),
      ('Centenary Bank', 17.5),
      ('DFCU Bank', 16.0),
      ('Equity Bank', 15.5),
    ];

    bool submitting = false;
    String? loanError;
    Map<String, dynamic>? loanResult;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final loanAmount = (ltvPercent / 100) * collateralValue;
          final rate = lenders[selectedLender].$2;
          final r = rate / 100 / 12;
          final n = repaymentMonths;
          final monthly = r == 0
              ? loanAmount / n
              : loanAmount * r * _pow(1 + r, n) / (_pow(1 + r, n) - 1);
          final scheme = Theme.of(ctx).colorScheme;

          Future<void> submit() async {
            setS(() { submitting = true; loanError = null; });
            try {
              final resp = await http.post(
                Uri.parse('${AppConfig.apiBaseUrl}/loans'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'token_id': contract.id,
                  'asset_id': contract.id,
                  'farmer_id': contract.farmerName,
                  'loan_amount': loanAmount,
                  'currency': contract.currency,
                  'collateral_value': collateralValue,
                  'ltv_percent': ltvPercent,
                  'repayment_months': repaymentMonths,
                  'interest_rate': rate,
                  'monthly_payment': monthly,
                  'lender': lenders[selectedLender].$1,
                  'crop_type': contract.crop,
                }),
              ).timeout(const Duration(seconds: 15));

              if (resp.statusCode >= 400) {
                final b = jsonDecode(resp.body);
                throw Exception((b['detail'] ?? b['message'] ?? 'Failed').toString());
              }
              setS(() { loanResult = jsonDecode(resp.body) as Map<String, dynamic>; });
            } catch (e) {
              setS(() => loanError = e.toString());
            } finally {
              setS(() => submitting = false);
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: loanResult != null
                  ? _loanSuccess(ctx, loanResult!, scheme)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Apply for Loan',
                            style: Theme.of(ctx).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('Contract ${contract.id} pledged as collateral',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 16),

                        // Collateral summary
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade100),
                          ),
                          child: Row(children: [
                            Icon(Icons.inventory_2_outlined,
                                color: Colors.purple.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${contract.crop} — '
                                '${contract.quantityKg.toStringAsFixed(0)} kg  •  '
                                'Value: ${collateralValue.toStringAsFixed(0)} ${contract.currency}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.purple.shade800),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // LTV
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Loan Amount',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant)),
                            Text(
                              '${loanAmount.toStringAsFixed(0)} ${contract.currency} (${ltvPercent.toInt()}%)',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.purple.shade700),
                            ),
                          ],
                        ),
                        Slider(
                          value: ltvPercent,
                          min: 30,
                          max: 80,
                          divisions: 10,
                          label: '${ltvPercent.toInt()}%',
                          activeColor: Colors.purple.shade700,
                          onChanged: (v) => setS(() => ltvPercent = v),
                        ),

                        // Repayment
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Repayment',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant)),
                            Text('$repaymentMonths months',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.purple.shade700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [3, 6, 12, 24]
                              .map((m) => ChoiceChip(
                                    label: Text('${m}mo'),
                                    selected: m == repaymentMonths,
                                    selectedColor: Colors.purple.shade100,
                                    onSelected: (_) =>
                                        setS(() => repaymentMonths = m),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),

                        // Lender
                        Text('Select Lender',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface)),
                        const SizedBox(height: 8),
                        ...lenders.asMap().entries.map((e) {
                          final sel = e.key == selectedLender;
                          return GestureDetector(
                            onTap: () => setS(() => selectedLender = e.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: sel
                                    ? Colors.purple.withOpacity(0.06)
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel
                                      ? Colors.purple.shade400
                                      : scheme.outlineVariant.withOpacity(0.4),
                                  width: sel ? 2 : 1,
                                ),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Text(e.value.$1,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                                Text(
                                  '${e.value.$2.toStringAsFixed(1)}% p.a.',
                                  style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w700),
                                ),
                                if (sel) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.check_circle,
                                      color: Colors.purple.shade600, size: 18),
                                ],
                              ]),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),

                        // Summary box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            _row(ctx, 'Loan Amount',
                                '${loanAmount.toStringAsFixed(0)} ${contract.currency}'),
                            _row(ctx, 'Interest Rate',
                                '${rate.toStringAsFixed(1)}% p.a.'),
                            _row(ctx, 'Monthly Payment',
                                '${monthly.toStringAsFixed(0)} ${contract.currency}'),
                            _row(ctx, 'Lender', lenders[selectedLender].$1),
                          ]),
                        ),

                        if (loanError != null) ...[
                          const SizedBox(height: 10),
                          Text(loanError!,
                              style: TextStyle(color: Colors.red.shade700,
                                  fontSize: 12)),
                        ],
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: submitting ? null : submit,
                            icon: submitting
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send_outlined),
                            label: Text(submitting
                                ? 'Submitting…'
                                : 'Submit Application'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.purple.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _loanSuccess(
      BuildContext ctx, Map<String, dynamic> r, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Icon(Icons.check_circle, color: Colors.green.shade600, size: 56),
        const SizedBox(height: 12),
        Text('Application Submitted!',
            style: Theme.of(ctx)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(r['message']?.toString() ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 16),
        _row(ctx, 'Loan ID', r['loan_id']?.toString() ?? '-'),
        _row(ctx, 'Amount',
            '${(r['loan_amount'] as num?)?.toStringAsFixed(0) ?? '-'} ${r['currency'] ?? ''}'),
        _row(ctx, 'Lender', r['lender']?.toString() ?? '-'),
        _row(ctx, 'Status', r['status']?.toString() ?? 'PENDING'),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ),
      ]),
    );
  }

  Widget _row(BuildContext ctx, String label, String value) {
    final scheme = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  double _pow(double base, int exp) {
    double r = 1;
    for (var i = 0; i < exp; i++) r *= base;
    return r;
  }
}
