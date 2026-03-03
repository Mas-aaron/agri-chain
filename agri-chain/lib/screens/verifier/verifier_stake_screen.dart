// Verifier stake management screen — stake tokens to increase verifier weight.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';

class VerifierStakeScreen extends StatefulWidget {
  const VerifierStakeScreen({super.key});

  @override
  State<VerifierStakeScreen> createState() => _VerifierStakeScreenState();
}

class _VerifierStakeScreenState extends State<VerifierStakeScreen> {
  final _amountCtl = TextEditingController();
  int _lockDays = 30;
  bool _staking = false;

  @override
  void dispose() {
    _amountCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prov = context.watch<VerifierProvider>();
    final verifier = prov.verifier;

    return Scaffold(
      appBar: AppBar(title: const Text('Stake Management')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current stake info ───────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade700, Colors.orange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    '${verifier?.stakeAmount.toStringAsFixed(0) ?? '0'} AYT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total Staked',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _infoChip('Reputation',
                          '${verifier?.reputationScore ?? 500}', Colors.white24),
                      const SizedBox(width: 12),
                      _infoChip(
                          'Weight Bonus',
                          '+${((verifier?.stakeAmount ?? 0) / 10000).toStringAsFixed(2)}',
                          Colors.white24),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Stake form ──────────────────────────────────────
            const Text('Add Stake',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Higher stakes increase your voting weight in consensus.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _amountCtl,
              decoration: const InputDecoration(
                labelText: 'Amount (AYT)',
                hintText: 'e.g. 500',
                prefixIcon: Icon(Icons.token),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _lockDays,
              decoration: const InputDecoration(
                labelText: 'Lock Period',
                prefixIcon: Icon(Icons.timer),
              ),
              items: const [
                DropdownMenuItem(value: 7, child: Text('7 days')),
                DropdownMenuItem(value: 14, child: Text('14 days')),
                DropdownMenuItem(value: 30, child: Text('30 days')),
                DropdownMenuItem(value: 90, child: Text('90 days (1.5× bonus)')),
                DropdownMenuItem(value: 180, child: Text('180 days (2× bonus)')),
              ],
              onChanged: (v) => setState(() => _lockDays = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _staking ? null : _doStake,
                icon: _staking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.lock),
                label: Text(_staking ? 'Staking…' : 'Stake Tokens'),
              ),
            ),

            const SizedBox(height: 32),

            // ── How staking works ──────────────────────────────
            const Text('How Staking Works',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _howItWorksItem(
                Icons.trending_up, 'Increased Weight',
                'Staked tokens increase your vote weight in consensus calculations.'),
            _howItWorksItem(
                Icons.shield, 'Skin in the Game',
                'Stakes can be slashed for consistently inaccurate submissions.'),
            _howItWorksItem(
                Icons.emoji_events, 'Higher Rewards',
                'Larger stakes qualify for accuracy bonuses and submission fees.'),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _howItWorksItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doStake() async {
    final text = _amountCtl.text.trim();
    if (text.isEmpty || double.tryParse(text) == null || double.parse(text) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid positive amount'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _staking = true);
    try {
      await context.read<VerifierProvider>().stakeTokens(
            double.parse(text),
            lockDays: _lockDays,
          );
      if (!mounted) return;
      _amountCtl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Tokens staked successfully'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _staking = false);
    }
  }
}
