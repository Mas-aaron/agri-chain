import 'package:flutter/material.dart';

/// Widget displaying portfolio summary metrics
class PortfolioSummary extends StatelessWidget {
  final double totalValue;
  final int assetCount;
  final double averageConfidence;

  const PortfolioSummary({
    super.key,
    required this.totalValue,
    required this.assetCount,
    required this.averageConfidence,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Portfolio Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SummaryMetric(
                    label: 'Total Value',
                    value: '\$${totalValue.toStringAsFixed(2)}',
                    icon: Icons.trending_up,
                  ),
                  _SummaryMetric(
                    label: 'Assets',
                    value: '$assetCount',
                    icon: Icons.inventory_2,
                  ),
                  _SummaryMetric(
                    label: 'Avg. Confidence',
                    value: '${(averageConfidence * 100).toStringAsFixed(0)}%',
                    icon: Icons.verified,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual summary metric widget
class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
