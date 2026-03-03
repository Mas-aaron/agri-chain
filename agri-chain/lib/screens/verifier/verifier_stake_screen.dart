import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VerifierProvider>().loadDashboardData();
    });
  }

  Future<void> _stake() async {
    final amount = double.tryParse(_amountCtl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    setState(() => _staking = true);
    try {
      await context.read<VerifierProvider>().stakeTokens(amount, _lockDays);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully staked ${amount.toStringAsFixed(0)} AYT!')),
        );
        _amountCtl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _staking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prov = context.watch<VerifierProvider>();
    final stats = prov.dashboardStats;
    final currentStake = (stats['stakeAmount'] ?? 0.0).toDouble();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            title: 'Token Staking',
            subtitle: 'Stake AYT tokens to increase your verification weight',
          ),
          const SizedBox(height: 16),

          // ── Current stake card ─────────────────────────
          GradientHeroCard(
            icon: Icons.lock,
            title: '${currentStake.toStringAsFixed(0)} AYT',
            subtitle: 'Currently staked',
            colors: [
              Colors.orange.withOpacity(0.14),
              scheme.primary.withOpacity(0.08),
            ],
          ),
          const SizedBox(height: 20),

          // ── Stake form ─────────────────────────────────
          const SectionHeader(title: 'New Stake'),
          const SizedBox(height: 12),
          ModernCard(
            child: Column(
              children: [
                TextField(
                  controller: _amountCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (AYT)',
                    prefixIcon: Icon(Icons.toll),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: _lockDays,
                  decoration: const InputDecoration(
                    labelText: 'Lock Period',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 days')),
                    DropdownMenuItem(value: 14, child: Text('14 days')),
                    DropdownMenuItem(value: 30, child: Text('30 days (recommended)')),
                    DropdownMenuItem(value: 90, child: Text('90 days (2x weight bonus)')),
                  ],
                  onChanged: (v) => setState(() => _lockDays = v!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _staking ? null : _stake,
                    icon: _staking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.lock),
                    label: Text(_staking ? 'Staking...' : 'Stake Tokens'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Info cards ─────────────────────────────────
          const SectionHeader(title: 'How Staking Works'),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.trending_up,
            title: 'Higher Weight',
            subtitle: 'Staked tokens increase your vote in consensus formation',
            trailing: const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          FeatureCard(
            icon: Icons.emoji_events,
            title: 'Earn Rewards',
            subtitle: 'Accurate verifiers earn AYT rewards proportional to stake',
            iconColor: Colors.amber.shade700,
            trailing: const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          FeatureCard(
            icon: Icons.shield_outlined,
            title: 'Slashing Protection',
            subtitle: 'Malicious or inaccurate reports may result in stake slashing',
            iconColor: Colors.red,
            trailing: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
