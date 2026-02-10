import 'package:flutter/material.dart';

import 'package:agri_chain/services/contracts_api_service.dart';
import 'package:agri_chain/widgets/modern_ui.dart';
import 'package:agri_chain/config/app_config.dart';

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
  const ContractsScreen({super.key});

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
    _future = _api.listContracts();
  }

  void _reload() {
    setState(() {
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
            onPressed: () async {
              try {
                await _api.createContract(
                  const ContractCreateRequest(
                    crop: 'Maize',
                    quantityKg: 1000,
                    unitPrice: 1200,
                    currency: 'UGX',
                    farmerName: 'Demo Farmer',
                  ),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract created')));
                _reload();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
              }
            },
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
                  imageUrl: 'https://source.unsplash.com/1200x700/?maize,corn,harvest',
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
                  imageUrl: 'https://source.unsplash.com/1200x700/?maize,corn,harvest',
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
                  imageUrl: 'https://source.unsplash.com/1200x700/?maize,corn,harvest',
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
                    imageUrl: 'https://source.unsplash.com/1200x700/?maize,corn,harvest',
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
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    await _api.purchaseContract(
                                      c.id,
                                      const ContractPurchaseRequest(buyerName: 'Demo Buyer'),
                                    );
                                    if (!context.mounted) return;
                                    _reload();
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
                                  }
                                },
                                icon: const Icon(Icons.shopping_cart_outlined),
                                label: const Text('Purchase'),
                              ),
                            if (c.status.toUpperCase() == 'PURCHASED')
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    await _api.deliverContract(
                                      c.id,
                                      const ContractDeliverRequest(actor: 'Logistics', ref: 'DEL-0001'),
                                    );
                                    if (!context.mounted) return;
                                    _reload();
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deliver failed: $e')));
                                  }
                                },
                                icon: const Icon(Icons.local_shipping_outlined),
                                label: const Text('Mark delivered'),
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
}
