import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final two = (int v) => v.toString().padLeft(2, '0');
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

        return RefreshIndicator(
          onRefresh: () async {
            await context.read<FieldsProvider>().ensureLoaded();
            await context.read<AlertsProvider>().ensureLoaded();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Here\'s what\'s happening today.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
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
    final two = (int v) => v.toString().padLeft(2, '0');
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
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
