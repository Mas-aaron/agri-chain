import 'package:flutter/material.dart';

import 'package:agri_chain/services/contracts_api_service.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class LedgerEvent {
  final String id;
  final DateTime time;
  final String action;
  final String actor;
  final String contractId;
  final Map<String, String> meta;

  const LedgerEvent({
    required this.id,
    required this.time,
    required this.action,
    required this.actor,
    required this.contractId,
    required this.meta,
  });
}

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  static const _defaultApiBaseUrl = 'http://10.0.2.2:8000';
  late final ContractsApiService _api;
  late Future<List<LedgerEventDto>> _future;

  @override
  void initState() {
    super.initState();
    _api = ContractsApiService.fromBaseUrl(_defaultApiBaseUrl);
    _future = _api.listLedger();
  }

  void _reload() {
    setState(() {
      _future = _api.listLedger();
    });
  }

  IconData _iconFor(String action) {
    final a = action.toLowerCase();
    if (a.contains('mint')) return Icons.auto_awesome;
    if (a.contains('purchase')) return Icons.shopping_cart_outlined;
    if (a.contains('delivery')) return Icons.local_shipping_outlined;
    return Icons.receipt_long_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger'),
      ),
      body: FutureBuilder<List<LedgerEventDto>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ImageHeroCard(
                  imageUrl: 'https://picsum.photos/seed/agrichain_ledger_header/1200/700',
                  title: 'Ledger',
                  subtitle: 'Track immutable contract events and status changes.',
                ),
                SizedBox(height: 16),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const ImageHeroCard(
                  imageUrl: 'https://picsum.photos/seed/agrichain_ledger_header/1200/700',
                  title: 'Ledger',
                  subtitle: 'Track immutable contract events and status changes.',
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Could not load ledger',
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
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  ImageHeroCard(
                    imageUrl: 'https://picsum.photos/seed/agrichain_ledger_header/1200/700',
                    title: 'Ledger',
                    subtitle: 'Track immutable contract events and status changes.',
                  ),
                  SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No ledger events yet. Create a contract first.'),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const ImageHeroCard(
                    imageUrl: 'https://picsum.photos/seed/agrichain_ledger_header/1200/700',
                    title: 'Ledger',
                    subtitle: 'Track immutable contract events and status changes.',
                  );
                }

                final e = items[i - 1];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(_iconFor(e.action), color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.action,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text('Actor: ${e.actor}', style: Theme.of(context).textTheme.bodySmall),
                              Text('Contract: ${e.contractId}', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: e.meta.entries
                                    .map(
                                      (kv) => Chip(
                                        label: Text('${kv.key}: ${kv.value}'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                          ),
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
}
