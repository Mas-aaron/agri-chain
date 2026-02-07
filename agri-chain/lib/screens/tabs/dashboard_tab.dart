import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';
import 'package:agri_chain/screens/blockchain/blockchain_hub_screen.dart';
import 'package:agri_chain/screens/yield_prediction_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String? _fieldName(BuildContext context, String? fieldId) {
    if (fieldId == null || fieldId.isEmpty) return null;
    final fields = context.read<FieldsProvider>().fields;
    final match = fields.where((f) => f.id == fieldId);
    if (match.isEmpty) return null;
    return match.first.name;
  }

  IconData _severityIcon(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('critical')) return Icons.error;
    if (s.contains('high')) return Icons.warning;
    return Icons.info_outline;
  }

  Color? _severityColor(BuildContext context, String severity) {
    final s = severity.toLowerCase();
    if (s.contains('critical')) return Colors.red;
    if (s.contains('high')) return Colors.orange;
    if (s.contains('medium')) return Theme.of(context).colorScheme.tertiary;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Future.wait([
        context.read<FieldsProvider>().ensureLoaded(),
        context.read<AlertsProvider>().ensureLoaded(),
      ]),
      builder: (context, snapshot) {
        final fieldsCount = context.watch<FieldsProvider>().fields.length;
        final alertsCount = context.watch<AlertsProvider>().alerts.length;
        final alerts = context.watch<AlertsProvider>().alerts;

        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return RefreshIndicator(
          onRefresh: () async {
            await context.read<FieldsProvider>().ensureLoaded();
            await context.read<AlertsProvider>().ensureLoaded();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DashboardHeader(isLoading: isLoading),
              const SizedBox(height: 16),
              _QuickActionsRow(),
              const SizedBox(height: 10),
              const _SecondaryActionsRow(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Active fields',
                      value: '$fieldsCount',
                      icon: Icons.map,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Pending alerts',
                      value: '$alertsCount',
                      icon: Icons.notifications,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(
                    child: _PlaceholderCard(
                      title: 'Weather',
                      subtitle: 'Coming soon',
                      icon: Icons.cloud,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _PlaceholderCard(
                      title: 'Market prices',
                      subtitle: 'Coming soon',
                      icon: Icons.show_chart,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RecentActivityCard(
                alerts: alerts.take(6).toList(),
                formatTime: _formatTime,
                fieldName: (fieldId) => _fieldName(context, fieldId),
                severityIcon: _severityIcon,
                severityColor: (severity) => _severityColor(context, severity),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool isLoading;

  const _DashboardHeader({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.dashboard_customize_outlined, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                isLoading ? 'Loading your farm summary…' : 'Here\'s what\'s happening today.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the bottom bar to open Scan.')),
              );
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Scan'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigation is handled by the bottom nav; keep this as a gentle hint.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the bottom bar to open Fields.')),
              );
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Fields'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const YieldPredictionScreen()),
              );
            },
            icon: const Icon(Icons.auto_graph_outlined),
            label: const Text('Yield'),
          ),
        ),
      ],
    );
  }
}

class _SecondaryActionsRow extends StatelessWidget {
  const _SecondaryActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockchainHubScreen()),
              );
            },
            icon: const Icon(Icons.hub_outlined),
            label: const Text('Blockchain'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the bottom bar to open Alerts.')),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Alerts'),
          ),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final List<AlertItem> alerts;
  final String Function(DateTime) formatTime;
  final String? Function(String?) fieldName;
  final IconData Function(String) severityIcon;
  final Color? Function(String) severityColor;

  const _RecentActivityCard({
    required this.alerts,
    required this.formatTime,
    required this.fieldName,
    required this.severityIcon,
    required this.severityColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              Text(
                'No recent activity yet. Scan a leaf to generate an alert.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...alerts.map((a) {
                final color = severityColor(a.severity);
                final fName = fieldName(a.fieldId);
                final subtitle = [
                  if (fName != null) fName,
                  a.isResolved ? 'Resolved' : 'Open',
                  formatTime(a.createdAt),
                ].join(' • ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      context.read<AlertsProvider>().markRead(a.id, isRead: true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _DashboardAlertDetailScreen(alertId: a.id)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              severityIcon(a.severity),
                              color: color ?? Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: a.isRead
                                            ? Theme.of(context).textTheme.bodyMedium
                                            : Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        a.severity,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: color ?? Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DashboardAlertDetailScreen extends StatelessWidget {
  final String alertId;

  const _DashboardAlertDetailScreen({required this.alertId});

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final alert = context.watch<AlertsProvider>().alerts.firstWhere((a) => a.id == alertId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: alert.isResolved ? 'Mark unresolved' : 'Mark resolved',
            icon: Icon(alert.isResolved ? Icons.check_circle : Icons.check_circle_outline),
            onPressed: () => context.read<AlertsProvider>().markResolved(alert.id, isResolved: !alert.isResolved),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(alert.message),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Category: ${alert.category}')),
                      Chip(label: Text('Severity: ${alert.severity}')),
                      Chip(label: Text('Time: ${_formatTime(alert.createdAt)}')),
                      Chip(label: Text(alert.isResolved ? 'Resolved' : 'Open')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PlaceholderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
