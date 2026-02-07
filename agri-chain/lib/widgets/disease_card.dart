import 'package:flutter/material.dart';

Color _alpha(Color c, double opacity) {
  final a = (opacity * 255).round().clamp(0, 255);
  return c.withAlpha(a);
}

class DiseaseCard extends StatelessWidget {
  final String diseaseName;
  final String severity;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  const DiseaseCard({
    super.key,
    required this.diseaseName,
    required this.severity,
    required this.color,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _alpha(color, 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon ?? Icons.spa_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  diseaseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _alpha(color, 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _alpha(color, 0.25)),
              ),
              child: Text(
                'Severity: $severity',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _supportText(severity),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: content,
        ),
      ),
    );
  }

  String _supportText(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('high')) return 'Act quickly: scout often and follow treatment guidance.';
    if (s.contains('medium')) return 'Monitor closely and intervene early if symptoms increase.';
    if (s.contains('low')) return 'Low risk: keep monitoring and maintain field hygiene.';
    if (s.contains('none')) return 'Good news: your crop looks healthy. Keep scouting weekly.';
    return 'Monitor your field regularly and act early.';
  }
}
