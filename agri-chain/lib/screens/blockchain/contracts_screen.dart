import 'package:flutter/material.dart';

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

class ContractsScreen extends StatelessWidget {
  const ContractsScreen({super.key});

  List<YieldContract> _demo() {
    final now = DateTime.now();
    return [
      YieldContract(
        id: 'FH-${now.millisecondsSinceEpoch - 20000}',
        crop: 'Maize',
        quantityKg: 1500,
        unitPrice: 1200,
        currency: 'UGX',
        status: 'LISTED',
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
      YieldContract(
        id: 'FH-${now.millisecondsSinceEpoch - 15000}',
        crop: 'Maize',
        quantityKg: 900,
        unitPrice: 1050,
        currency: 'UGX',
        status: 'PURCHASED',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      YieldContract(
        id: 'FH-${now.millisecondsSinceEpoch - 10000}',
        crop: 'Maize',
        quantityKg: 600,
        unitPrice: 1300,
        currency: 'UGX',
        status: 'DELIVERED',
        createdAt: now.subtract(const Duration(days: 2, hours: 4)),
      ),
    ];
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
    final items = _demo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contracts'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = items[i];
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
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
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
                ],
              ),
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
