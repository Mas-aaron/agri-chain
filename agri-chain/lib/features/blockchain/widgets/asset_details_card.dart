import 'package:flutter/material.dart';
import '../models/yield_asset.dart';

/// Detailed card widget for asset information
class AssetDetailsCard extends StatelessWidget {
  final YieldAsset asset;

  const AssetDetailsCard({
    super.key,
    required this.asset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              label: 'Asset ID',
              value: asset.assetId,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Farmer ID',
              value: asset.farmerId,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Crop Type',
              value: asset.cropType,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Season',
              value: asset.season.toString(),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Created',
              value: _formatDate(asset.createdAt),
            ),
            if (asset.updatedAt != null) ...[
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Updated',
                value: _formatDate(asset.updatedAt!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Detail row widget for displaying key-value pairs
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
