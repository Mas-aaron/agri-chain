// Reusable asset card widget for pending assets list.

import 'package:flutter/material.dart';

class AssetCard extends StatelessWidget {
  final Map<String, dynamic> asset;
  final VoidCallback onSubmit;

  const AssetCard({
    super.key,
    required this.asset,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.grass, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset['asset_id'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${asset['crop_type'] ?? '—'} · ${asset['season'] ?? '—'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (asset['predicted_yield'] != null)
                    Text(
                      'Predicted: ${asset['predicted_yield']} kg',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onSubmit,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
