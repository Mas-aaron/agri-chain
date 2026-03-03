import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class SubmissionHistoryScreen extends StatefulWidget {
  const SubmissionHistoryScreen({super.key});

  @override
  State<SubmissionHistoryScreen> createState() => _SubmissionHistoryScreenState();
}

class _SubmissionHistoryScreenState extends State<SubmissionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VerifierProvider>().loadSubmissionHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prov = context.watch<VerifierProvider>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => prov.loadSubmissionHistory(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(
              title: 'Submission History',
              subtitle: 'Your past yield verification reports',
            ),
            const SizedBox(height: 16),

            if (prov.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (prov.submissionHistory.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 56, color: scheme.primary.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No submissions yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit your first yield report from Pending Assets.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else
              for (final sub in prov.submissionHistory) ...[
                _SubmissionTile(sub: sub),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final Map<String, dynamic> sub;
  const _SubmissionTile({required this.sub});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = (sub['status'] ?? 'PENDING').toString().toUpperCase();
    final yieldVal = sub['submitted_yield'] ?? sub['submittedYield'] ?? 0;
    final confidence = sub['confidence'] ?? 0.0;
    final assetId = sub['asset_id'] ?? sub['assetId'] ?? '-';

    final statusColor = status == 'ACCEPTED'
        ? Colors.green
        : status == 'REJECTED'
            ? Colors.red
            : Colors.orange;

    return ModernCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              status == 'ACCEPTED'
                  ? Icons.check_circle
                  : status == 'REJECTED'
                      ? Icons.cancel
                      : Icons.schedule,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assetId.toString(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Yield: $yieldVal kg \u2022 Confidence: ${(confidence is num ? (confidence * 100).toStringAsFixed(0) : confidence)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
