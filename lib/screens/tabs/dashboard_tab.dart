import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

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
              const _PlaceholderCard(
                title: 'Recent activity',
                subtitle: 'Your scans and actions will appear here.',
                icon: Icons.history,
              ),
            ],
          ),
        );
      },
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
