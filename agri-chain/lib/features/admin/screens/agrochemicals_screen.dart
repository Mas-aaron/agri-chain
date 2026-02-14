import 'package:flutter/material.dart';

import '../models/agrochemical.dart';
import '../models/supplier.dart';
import '../services/agrochemical_repository.dart';
import '../services/supplier_repository.dart';

class AgrochemicalsScreen extends StatelessWidget {
  const AgrochemicalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AgrochemicalRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Agrochemicals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showDialog<void>(
            context: context,
            builder: (_) => _AgrochemicalDialog(
              title: 'New agrochemical',
              onSubmit: (data) async {
                await repo.createAgrochemical(
                  name: data.name,
                  activeIngredient: data.activeIngredient,
                  target: data.target,
                  usage: data.usage,
                  isCredited: data.isCredited,
                  approvedSupplierIds: data.approvedSupplierIds,
                );
              },
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add chemical'),
      ),
      body: StreamBuilder<List<Agrochemical>>(
        stream: repo.watchAgrochemicals(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chems = snapshot.data!;
          if (chems.isEmpty) {
            return const Center(child: Text('No agrochemicals yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final c = chems[i];
              final creditedText = c.isCredited ? 'Credited' : 'Inactive';
              final supplierCount = c.approvedSupplierIds.length;

              return Card(
                child: ListTile(
                  leading: Icon(
                    c.isCredited
                        ? Icons.verified_outlined
                        : Icons.block_outlined,
                  ),
                  title: Text(c.name.isEmpty ? '(No name)' : c.name),
                  subtitle: Text(
                    '${c.activeIngredient} • ${c.target}\nSuppliers: $supplierCount • $creditedText',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await showDialog<void>(
                          context: context,
                          builder: (_) => _AgrochemicalDialog(
                            title: 'Edit agrochemical',
                            initial: c,
                            onSubmit: (data) async {
                              await repo.updateAgrochemical(
                                Agrochemical(
                                  id: c.id,
                                  name: data.name,
                                  activeIngredient: data.activeIngredient,
                                  target: data.target,
                                  usage: data.usage,
                                  isCredited: data.isCredited,
                                  approvedSupplierIds: data.approvedSupplierIds,
                                ),
                              );
                            },
                          ),
                        );
                      }
                      if (value == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete agrochemical?'),
                            content: Text('This will remove “${c.name}”.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await repo.deleteAgrochemical(c.id);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: chems.length,
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object? error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Failed to load agrochemicals',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('Error: $error'),
        ],
      ),
    );
  }
}

class _AgrochemicalDialogData {
  final String name;
  final String activeIngredient;
  final String target;
  final String usage;
  final bool isCredited;
  final List<String> approvedSupplierIds;

  const _AgrochemicalDialogData({
    required this.name,
    required this.activeIngredient,
    required this.target,
    required this.usage,
    required this.isCredited,
    required this.approvedSupplierIds,
  });
}

class _AgrochemicalDialog extends StatefulWidget {
  final String title;
  final Agrochemical? initial;
  final Future<void> Function(_AgrochemicalDialogData data) onSubmit;

  const _AgrochemicalDialog({
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<_AgrochemicalDialog> createState() => _AgrochemicalDialogState();
}

class _AgrochemicalDialogState extends State<_AgrochemicalDialog> {
  late final TextEditingController _name;
  late final TextEditingController _active;
  late final TextEditingController _target;
  late final TextEditingController _usage;

  bool _credited = true;
  bool _saving = false;
  String? _error;

  final Set<String> _selectedSupplierIds = {};

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name = TextEditingController(text: c?.name ?? '');
    _active = TextEditingController(text: c?.activeIngredient ?? '');
    _target = TextEditingController(text: c?.target ?? '');
    _usage = TextEditingController(text: c?.usage ?? '');
    _credited = c?.isCredited ?? true;
    _selectedSupplierIds.addAll(c?.approvedSupplierIds ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    _active.dispose();
    _target.dispose();
    _usage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        _AgrochemicalDialogData(
          name: _name.text.trim(),
          activeIngredient: _active.text.trim(),
          target: _target.text.trim(),
          usage: _usage.text.trim(),
          isCredited: _credited,
          approvedSupplierIds: _selectedSupplierIds.toList(growable: false),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersRepo = SupplierRepository();

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _active,
              decoration:
                  const InputDecoration(labelText: 'Active ingredient'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              decoration: const InputDecoration(labelText: 'Target'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usage,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Usage'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _credited,
              onChanged: (v) => setState(() => _credited = v),
              title: const Text('Credited/Active'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Approved suppliers',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Supplier>>(
              stream: suppliersRepo.watchSuppliers(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Failed to load suppliers: ${snap.error}');
                }
                final suppliers = snap.data ?? const <Supplier>[];
                if (suppliers.isEmpty) {
                  return const Text('No suppliers available yet.');
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suppliers.map((s) {
                    final selected = _selectedSupplierIds.contains(s.id);
                    return FilterChip(
                      label: Text(s.name.isEmpty ? s.id : s.name),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedSupplierIds.add(s.id);
                          } else {
                            _selectedSupplierIds.remove(s.id);
                          }
                        });
                      },
                    );
                  }).toList(growable: false),
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
