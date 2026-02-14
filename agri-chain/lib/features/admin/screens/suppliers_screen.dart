import 'package:flutter/material.dart';

import '../models/supplier.dart';
import '../services/supplier_repository.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SupplierRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showDialog<void>(
            context: context,
            builder: (_) => _SupplierDialog(
              title: 'New supplier',
              onSubmit: (data) async {
                await repo.createSupplier(
                  name: data.name,
                  phone: data.phone,
                  location: data.location,
                  licenseId: data.licenseId,
                  isApproved: data.isApproved,
                );
              },
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add supplier'),
      ),
      body: StreamBuilder<List<Supplier>>(
        stream: repo.watchSuppliers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final suppliers = snapshot.data!;
          if (suppliers.isEmpty) {
            return const Center(child: Text('No suppliers yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final s = suppliers[i];
              final approvedText = s.isApproved ? 'Approved' : 'Inactive';
              return Card(
                child: ListTile(
                  leading: Icon(
                    s.isApproved
                        ? Icons.verified_outlined
                        : Icons.block_outlined,
                  ),
                  title: Text(s.name.isEmpty ? '(No name)' : s.name),
                  subtitle: Text(
                    '${s.location} • ${s.phone}\nLicense: ${s.licenseId} • $approvedText',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await showDialog<void>(
                          context: context,
                          builder: (_) => _SupplierDialog(
                            title: 'Edit supplier',
                            initial: s,
                            onSubmit: (data) async {
                              await repo.upsertSupplier(
                                Supplier(
                                  id: s.id,
                                  name: data.name,
                                  phone: data.phone,
                                  location: data.location,
                                  licenseId: data.licenseId,
                                  isApproved: data.isApproved,
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
                            title: const Text('Delete supplier?'),
                            content: Text(
                              'This will remove “${s.name}”.',
                            ),
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
                          await repo.deleteSupplier(s.id);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: suppliers.length,
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
            'Failed to load suppliers',
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

class _SupplierDialogData {
  final String name;
  final String phone;
  final String location;
  final String licenseId;
  final bool isApproved;

  const _SupplierDialogData({
    required this.name,
    required this.phone,
    required this.location,
    required this.licenseId,
    required this.isApproved,
  });
}

class _SupplierDialog extends StatefulWidget {
  final String title;
  final Supplier? initial;
  final Future<void> Function(_SupplierDialogData data) onSubmit;

  const _SupplierDialog({
    required this.title,
    required this.onSubmit,
    this.initial,
  });

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  late final TextEditingController _licenseId;
  bool _approved = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _name = TextEditingController(text: s?.name ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _location = TextEditingController(text: s?.location ?? '');
    _licenseId = TextEditingController(text: s?.licenseId ?? '');
    _approved = s?.isApproved ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _licenseId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        _SupplierDialogData(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          location: _location.text.trim(),
          licenseId: _licenseId.text.trim(),
          isApproved: _approved,
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
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _licenseId,
              decoration: const InputDecoration(labelText: 'License ID'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _approved,
              onChanged: (v) => setState(() => _approved = v),
              title: const Text('Approved/Active'),
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
