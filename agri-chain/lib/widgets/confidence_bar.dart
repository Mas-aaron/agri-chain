import 'package:flutter/material.dart';

class ConfidenceBar extends StatelessWidget {
  final String label;
  final double percentage;
  final bool isTop;

  const ConfidenceBar({
    super.key,
    required this.label,
    required this.percentage,
    this.isTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = percentage.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            Text('${pct.toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: isTop ? Colors.green : Colors.green.shade300,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
