import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/models/verifier_models.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class VerifierProfileScreen extends StatefulWidget {
  const VerifierProfileScreen({super.key});

  @override
  State<VerifierProfileScreen> createState() => _VerifierProfileScreenState();
}

class _VerifierProfileScreenState extends State<VerifierProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VerifierProvider>()
        ..loadProfile()
        ..loadRewards();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prov = context.watch<VerifierProvider>();
    final profile = prov.profile;
    final stats = prov.dashboardStats;
    final rewards = prov.rewards;

    final orgName = profile['organization_name'] ?? profile['organizationName'] ?? 'Verifier';
    final orgType = profile['organization_type'] ?? profile['organizationType'] ?? '-';
    final email = FirebaseAuth.instance.currentUser?.email ?? '-';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await prov.loadProfile();
          await prov.loadRewards();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Profile'),
            const SizedBox(height: 16),

            // ── Avatar + name ────────────────────────────
            ModernCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primary.withOpacity(0.12),
                    child: Text(
                      orgName.isNotEmpty ? orgName[0].toUpperCase() : 'V',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orgName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(orgType, style: Theme.of(context).textTheme.bodySmall),
                        Text(email, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Stats ────────────────────────────────────
            const SectionHeader(title: 'Performance'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                MiniStatTile(
                  label: 'Reputation',
                  value: '${stats['reputationScore'] ?? 500}',
                  icon: Icons.star,
                ),
                MiniStatTile(
                  label: 'Submissions',
                  value: '${stats['totalSubmissions'] ?? 0}',
                  icon: Icons.assignment_turned_in,
                ),
                MiniStatTile(
                  label: 'Staked',
                  value: '${(stats['stakeAmount'] ?? 0.0).toStringAsFixed(0)} AYT',
                  icon: Icons.lock,
                ),
                MiniStatTile(
                  label: 'Rewards',
                  value: '${(stats['rewardsEarned'] ?? 0.0).toStringAsFixed(1)} AYT',
                  icon: Icons.emoji_events,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Recent Rewards ───────────────────────────
            const SectionHeader(title: 'Recent Rewards'),
            const SizedBox(height: 12),

            if (rewards.isEmpty)
              ModernCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No rewards yet. Submit accurate reports to earn AYT!',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              for (final r in rewards.take(5)) ...[
                ModernCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.reason,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+${r.amount.toStringAsFixed(1)} AYT',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

            const SizedBox(height: 24),

            // ── Sign out ─────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
