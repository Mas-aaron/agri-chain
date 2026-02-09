import 'package:flutter/material.dart';
import '../models/yield_asset.dart';
import '../widgets/asset_details_card.dart';
import '../widgets/status_badge.dart';

/// Detailed view screen for a single yield asset
class YieldDetailsScreen extends StatelessWidget {
  final YieldAsset asset;

  const YieldDetailsScreen({
    super.key,
    required this.asset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(asset.cropType),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card with basic info
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Token ID',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              asset.tokenId,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        StatusBadge(status: asset.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Season ${asset.season}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Metrics Grid
            Text(
              'Yield Metrics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _MetricCard(
                  label: 'Predicted Yield',
                  value: '${asset.predictedYield.toStringAsFixed(0)} kg',
                  color: Colors.blue,
                ),
                _MetricCard(
                  label: 'Confidence',
                  value: '${(asset.confidence * 100).toStringAsFixed(1)}%',
                  color: Colors.green,
                ),
                _MetricCard(
                  label: 'Token Amount',
                  value: asset.tokenAmount.toStringAsFixed(0),
                  color: Colors.orange,
                ),
                _MetricCard(
                  label: 'Current Value',
                  value: '\$${asset.currentValue.toStringAsFixed(2)}',
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Asset Details
            Text(
              'Asset Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            AssetDetailsCard(asset: asset),
            const SizedBox(height: 20),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Trading feature coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Trade Tokens'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Loan feature coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.savings),
                label: const Text('Use as Collateral'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Metric card widget for displaying individual metrics
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
