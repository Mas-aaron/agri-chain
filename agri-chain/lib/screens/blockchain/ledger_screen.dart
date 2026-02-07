import 'package:flutter/material.dart';

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

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  List<LedgerEvent> _demo() {
    final now = DateTime.now();
    return [
      LedgerEvent(
        id: 'L-${now.millisecondsSinceEpoch - 30000}',
        time: now.subtract(const Duration(days: 2, hours: 4)),
        action: 'MINT_AND_LIST',
        actor: 'Kato Farms',
        contractId: 'FH-${now.millisecondsSinceEpoch - 10000}',
        meta: const {'proof': 'obsHash: ***'},
      ),
      LedgerEvent(
        id: 'L-${now.millisecondsSinceEpoch - 25000}',
        time: now.subtract(const Duration(days: 1, hours: 2)),
        action: 'PURCHASE',
        actor: 'GreenMart Exporters',
        contractId: 'FH-${now.millisecondsSinceEpoch - 15000}',
        meta: const {'amount': '945000 UGX'},
      ),
      LedgerEvent(
        id: 'L-${now.millisecondsSinceEpoch - 20000}',
        time: now.subtract(const Duration(hours: 6)),
        action: 'DELIVERY_RECORDED',
        actor: 'Logistics',
        contractId: 'FH-${now.millisecondsSinceEpoch - 10000}',
        meta: const {'ref': 'LOG-00021'},
      ),
    ];
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
    final items = _demo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = items[i];
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
  }
}
