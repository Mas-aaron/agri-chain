import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';
import 'package:agri_chain/widgets/modern_ui.dart';
import 'package:agri_chain/screens/rover/field_map_screen.dart';

class FieldsTab extends StatelessWidget {
  const FieldsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FieldsProvider>();
    final fields = provider.fields;

    return Scaffold(
      appBar: AppBar(title: const Text('Fields')),
      body: FutureBuilder<void>(
        future: context.read<FieldsProvider>().ensureLoaded(),
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.all(16),
          children: [
            const ImageHeroCard(
              imageUrl: 'https://images.unsplash.com/photo-1595847321528-766cf018aeb5?w=800&q=80',
              title: 'Your fields',
              subtitle: 'Track each plot, monitor location, and link alerts to fields.',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fields', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                FilledButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (fields.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No fields yet. Add your first field to track health and alerts.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...fields.map((f) {
                final location = f.location.isEmpty ? 'Unknown location' : f.location;
                final sizeText = (f.sizeHa == null) ? '' : ' • ${f.sizeHa!.toStringAsFixed(2)} ha';
                return ImageFeatureCard(
                  imageUrl: 'https://images.unsplash.com/photo-1581001808603-9d8f3ec200bc?w=800&q=80',
                  title: f.name,
                  subtitle: '$location • ${f.crop}$sizeText',
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _openEditor(context, existing: f);
                      } else if (value == 'delete') {
                        await context.read<FieldsProvider>().removeField(f.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => FieldDetailScreen(field: f)),
                    );
                  },
                );
              }),
          ],
        );
      },
    ),
  );
}

  Future<void> _openEditor(BuildContext context, {FieldItem? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final locationController = TextEditingController(text: existing?.location ?? '');
    final cropController = TextEditingController(text: existing?.crop ?? 'Maize');
    final sizeController = TextEditingController(
      text: existing?.sizeHa == null ? '' : existing!.sizeHa!.toStringAsFixed(2),
    );

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add field' : 'Edit field'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Field name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cropController,
                  decoration: const InputDecoration(labelText: 'Crop'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: sizeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Field size (ha, optional)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) return 'Enter a valid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    final sizeHa = sizeController.text.trim().isEmpty ? null : double.tryParse(sizeController.text.trim());

    if (existing == null) {
      final field = FieldItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        crop: cropController.text.trim(),
        sizeHa: sizeHa,
        createdAt: DateTime.now(),
      );
      await context.read<FieldsProvider>().addField(field);
      return;
    }

    final updated = existing.copyWith(
      name: nameController.text.trim(),
      location: locationController.text.trim(),
      crop: cropController.text.trim(),
      sizeHa: sizeHa,
    );
    await context.read<FieldsProvider>().updateField(updated);
  }
}

class FieldDetailScreen extends StatelessWidget {
  final FieldItem field;

  const FieldDetailScreen({required this.field});

  @override
  Widget build(BuildContext context) {
    final location = field.location.isEmpty ? 'Unknown location' : field.location;
    final size = field.sizeHa == null ? '—' : '${field.sizeHa!.toStringAsFixed(2)} ha';

    final alertsProvider = context.watch<AlertsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await const FieldsTab()._openEditor(context, existing: field);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await context.read<FieldsProvider>().removeField(field.id);
              if (context.mounted) Navigator.pop(context);
            },
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
                  Text(field.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Crop: ${field.crop}')),
                      Chip(label: Text('Location: $location')),
                      Chip(label: Text('Size: $size')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FieldMapScreen()),
                        );
                      },
                      icon: const Icon(Icons.satellite_alt),
                      label: const Text('Map Field Boundary (Manual/Rover)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<void>(
            future: alertsProvider.ensureLoaded(),
            builder: (context, snapshot) {
              final allAlerts = alertsProvider.alertsForField(field.id);
              final activeAlerts = allAlerts.where((a) => !a.isResolved && a.severity.toLowerCase() != 'low').toList();
              final history = allAlerts;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (activeAlerts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No active alerts for this field. Crop is healthy!'),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Active alerts', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ...activeAlerts.take(5).map(
                              (a) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  a.severity.toLowerCase().contains('critical')
                                      ? Icons.error
                                      : Icons.warning,
                                  color: a.severity.toLowerCase().contains('critical')
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                                title: Text(a.title),
                                subtitle: Text(a.message, maxLines: 1, overflow: TextOverflow.ellipsis),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => _FieldAlertDetailScreen(alert: a)),
                                  );
                                },
                              ),
                            ),
                            if (activeAlerts.length > 5)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Showing 5 of ${activeAlerts.length}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Health History', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (history.isEmpty)
                            Text('No scans or events recorded for this field yet.', style: Theme.of(context).textTheme.bodySmall)
                          else
                            ...history.map((record) {
                              final isHealthy = record.severity.toLowerCase() == 'low';
                              final dateStr = '${record.createdAt.day}/${record.createdAt.month}/${record.createdAt.year}';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: isHealthy ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                  child: Icon(
                                    isHealthy ? Icons.eco : Icons.bug_report,
                                    color: isHealthy ? Colors.green : Colors.orange,
                                  ),
                                ),
                                title: Text(isHealthy ? 'Healthy Scan' : 'Disease Detected'),
                                subtitle: Text('$dateStr • ${record.title.replaceAll('AI Health Alert: ', '').replaceAll('Manual Alert: ', '')}'),
                                trailing: const Icon(Icons.chevron_right, size: 16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => _FieldAlertDetailScreen(alert: record)),
                                  );
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Field health history (placeholder).'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldAlertDetailScreen extends StatelessWidget {
  final AlertItem alert;

  const _FieldAlertDetailScreen({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert')),
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
                      Chip(label: Text('Severity: ${alert.severity}')),
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
