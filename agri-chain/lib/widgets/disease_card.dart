import 'package:flutter/material.dart';

Color _alpha(Color c, double opacity) {
  final a = (opacity * 255).round().clamp(0, 255);
  return c.withAlpha(a);
}

class DiseaseCard extends StatelessWidget {
  final String diseaseName;
  final String severity;
  final Color color;

  const DiseaseCard({
    super.key,
    required this.diseaseName,
    required this.severity,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _alpha(color, 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diseaseName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Severity: $severity',
            style: TextStyle(color: _alpha(color, 0.8)),
          ),
        ],
      ),
    );
  }
}
