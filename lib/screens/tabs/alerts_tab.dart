import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';

import 'package:agri_chain/providers/alerts_provider.dart';

enum _AlertsFilter { all, unread, critical }

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  _AlertsFilter _filter = _AlertsFilter.all;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: context.read<AlertsProvider>().ensureLoaded(),
      builder: (context, snapshot) {
        final provider = context.watch<AlertsProvider>();
        final allAlerts = provider.alerts;
        final alerts = _applyFilter(allAlerts);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Alerts', style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: alerts.isEmpty
                      ? null
                      : () async => context.read<AlertsProvider>().clearAll(),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == _AlertsFilter.all,
                  onSelected: (_) => setState(() => _filter = _AlertsFilter.all),
                ),
                ChoiceChip(
                  label: Text('Unread (${provider.unreadCount})'),
                  selected: _filter == _AlertsFilter.unread,
                  onSelected: (_) => setState(() => _filter = _AlertsFilter.unread),
                ),
                ChoiceChip(
                  label: const Text('Critical'),
                  selected: _filter == _AlertsFilter.critical,
                  onSelected: (_) => setState(() => _filter = _AlertsFilter.critical),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No alerts yet. Scan a leaf to generate an AI health alert.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...alerts.map((a) {
                return Card(
                  child: ListTile(
                    leading: _severityIcon(a.severity),
                    title: Text(
                      a.title,
                      style: a.isRead
                          ? Theme.of(context).textTheme.bodyLarge
                          : Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${a.category} • ${_formatTime(a.createdAt)}'),
                    onTap: () {
                      context.read<AlertsProvider>().markRead(a.id, isRead: true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _AlertDetailScreen(alert: a),
                        ),
                      );
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'toggle_read') {
                          await context.read<AlertsProvider>().markRead(a.id, isRead: !a.isRead);
                        } else if (value == 'toggle_resolved') {
                          await context.read<AlertsProvider>().markResolved(a.id, isResolved: !a.isResolved);
                        } else if (value == 'delete') {
                          await context.read<AlertsProvider>().removeAlert(a.id);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'toggle_read',
                          child: Text(a.isRead ? 'Mark as unread' : 'Mark as read'),
                        ),
                        PopupMenuItem(
                          value: 'toggle_resolved',
                          child: Text(a.isResolved ? 'Mark as unresolved' : 'Mark as resolved'),
                        ),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  List<AlertItem> _applyFilter(List<AlertItem> input) {
    switch (_filter) {
      case _AlertsFilter.unread:
        return input.where((a) => !a.isRead).toList();
      case _AlertsFilter.critical:
        return input.where((a) => a.severity.toLowerCase().contains('critical')).toList();
      case _AlertsFilter.all:
      default:
        return input;
    }
  }

  Widget _severityIcon(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('critical')) {
      return const Icon(Icons.error, color: Colors.red);
    }
    if (s.contains('high')) {
      return const Icon(Icons.warning, color: Colors.orange);
    }
    return const Icon(Icons.info_outline);
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _AlertDetailScreen extends StatelessWidget {
  final AlertItem alert;

  const _AlertDetailScreen({required this.alert});

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  List<Map<String, dynamic>> _top3() {
    final raw = alert.extra?['top3'];
    if (raw is List) {
      return raw.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _top3();
    final latest = context.watch<AlertsProvider>().alerts.firstWhere(
          (a) => a.id == alert.id,
          orElse: () => alert,
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert details'),
        actions: [
          IconButton(
            tooltip: latest.isRead ? 'Mark unread' : 'Mark read',
            icon: Icon(latest.isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined),
            onPressed: () => context.read<AlertsProvider>().markRead(latest.id, isRead: !latest.isRead),
          ),
          IconButton(
            tooltip: latest.isResolved ? 'Mark unresolved' : 'Mark resolved',
            icon: Icon(latest.isResolved ? Icons.check_circle : Icons.check_circle_outline),
            onPressed: () => context.read<AlertsProvider>().markResolved(latest.id, isResolved: !latest.isResolved),
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
                  Text(latest.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(latest.message, style: Theme.of(context).textTheme.bodyMedium),
                  if (latest.imagePath != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(latest.imagePath!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Category: ${latest.category}')),
                      Chip(label: Text('Severity: ${latest.severity}')),
                      Chip(label: Text('Time: ${_formatTime(latest.createdAt)}')),
                      Chip(label: Text(latest.isResolved ? 'Resolved' : 'Open')),
                    ],
                  ),
                  if (top3.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Top predictions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...top3.map((p) {
                      final label = (p['label'] as String?) ?? 'Unknown';
                      final confText = (p['confidenceText'] as String?) ?? (p['confidence']?.toString() ?? '—');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
                            Text(confText, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('AI recommendations (placeholder).'),
            ),
          ),
        ],
      ),
    );
  }
}
