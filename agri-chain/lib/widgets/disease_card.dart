import 'package:flutter/material.dart';

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
        color: color.withOpacity(0.1),
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
            style: TextStyle(color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
