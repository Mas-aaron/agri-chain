// Verifier profile screen — view/edit verifier profile.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';

class VerifierProfileScreen extends StatefulWidget {
  const VerifierProfileScreen({super.key});

  @override
  State<VerifierProfileScreen> createState() => _VerifierProfileScreenState();
}

class _VerifierProfileScreenState extends State<VerifierProfileScreen> {
  bool _editing = false;
  final _orgNameCtl = TextEditingController();
  String _orgType = 'INSPECTOR';

  static const _orgTypes = ['GOVERNMENT', 'UNIVERSITY', 'SATELLITE', 'INSPECTOR', 'COOPERATIVE'];

  @override
  void initState() {
    super.initState();
    final prov = context.read<VerifierProvider>();
    if (prov.verifier != null) {
      _orgNameCtl.text = prov.verifier!.organizationName;
      _orgType = prov.verifier!.organizationType;
    }
    prov.loadRewards();
  }

  @override
  void dispose() {
    _orgNameCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prov = context.watch<VerifierProvider>();
    final v = prov.verifier;

    if (v == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Not registered as verifier')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifier Profile'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.close : Icons.edit),
            onPressed: () => setState(() {
              _editing = !_editing;
              if (!_editing) {
                _orgNameCtl.text = v.organizationName;
                _orgType = v.organizationType;
              }
            }),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Avatar + name ───────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: scheme.primary,
                    child: Text(
                      v.organizationName.isNotEmpty
                          ? v.organizationName[0].toUpperCase()
                          : 'V',
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    v.organizationName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      v.organizationType,
                      style: TextStyle(
                          color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('ID: ${v.userId}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Stats ───────────────────────────────────────────
            _statRow('Reputation Score', '${v.reputationScore} / 1000'),
            _statRow('Total Submissions', '${v.totalSubmissions}'),
            _statRow('Accuracy Rate', '${(v.accuracyRate * 100).toStringAsFixed(1)}%'),
            _statRow('Staked Amount', '${v.stakeAmount.toStringAsFixed(0)} AYT'),
            _statRow('Total Rewards', '${prov.totalRewards.toStringAsFixed(0)} AYT'),
            _statRow('Status', v.isActive ? 'Active ✅' : 'Suspended ❌'),
            _statRow('Joined', v.createdAt.split('T').first),

            // ── Edit form ───────────────────────────────────────
            if (_editing) ...[
              const SizedBox(height: 28),
              const Text('Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _orgNameCtl,
                decoration: const InputDecoration(labelText: 'Organization Name'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _orgType,
                decoration: const InputDecoration(labelText: 'Organization Type'),
                items: _orgTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _orgType = v!),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save Changes'),
                ),
              ),
            ],

            // ── Recent rewards ──────────────────────────────────
            const SizedBox(height: 28),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Rewards',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            if (prov.rewards.isEmpty)
              Text('No rewards yet', style: TextStyle(color: Colors.grey.shade500))
            else
              for (final r in prov.rewards.take(10))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      r.reason == 'ACCURACY_BONUS' ? Icons.emoji_events : Icons.paid,
                      color: r.reason == 'ACCURACY_BONUS' ? Colors.amber : Colors.green,
                    ),
                    title: Text('+${r.amount.toStringAsFixed(0)} AYT'),
                    subtitle: Text(r.reason.replaceAll('_', ' ')),
                    trailing: Text(
                      r.createdAt.split('T').first,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final prov = context.read<VerifierProvider>();
    await prov.updateProfile({
      'organization_name': _orgNameCtl.text.trim(),
      'organization_type': _orgType,
    });
    if (mounted) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profile updated'), backgroundColor: Colors.green),
      );
    }
  }
}
