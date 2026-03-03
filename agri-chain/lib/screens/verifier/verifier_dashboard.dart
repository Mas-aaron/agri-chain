// Independent Verifier Dashboard — main entry screen for verifiers.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/screens/verifier/widgets/stats_card.dart';
import 'package:agri_chain/screens/verifier/widgets/asset_card.dart';
import 'package:agri_chain/screens/verifier/widgets/submission_card.dart';
import 'package:agri_chain/screens/verifier/pending_assets_screen.dart';
import 'package:agri_chain/screens/verifier/submit_report_screen.dart';
import 'package:agri_chain/screens/verifier/submission_history_screen.dart';
import 'package:agri_chain/screens/verifier/verifier_stake_screen.dart';
import 'package:agri_chain/screens/verifier/verifier_profile_screen.dart';

class VerifierDashboard extends StatefulWidget {
  const VerifierDashboard({super.key});

  @override
  State<VerifierDashboard> createState() => _VerifierDashboardState();
}

class _VerifierDashboardState extends State<VerifierDashboard> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<VerifierProvider>();
      if (prov.verifier != null) {
        prov.loadDashboardData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prov = context.watch<VerifierProvider>();

    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: [
          _DashboardBody(prov: prov),
          const PendingAssetsScreen(),
          const SubmissionHistoryScreen(),
          const VerifierStakeScreen(),
          const VerifierProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.assignment_rounded), label: 'Assets'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'History'),
          NavigationDestination(icon: Icon(Icons.lock_rounded), label: 'Stake'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── Dashboard body ──────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final VerifierProvider prov;
  const _DashboardBody({required this.prov});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (prov.isLoading && prov.dashboardStats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = prov.dashboardStats;
    final totalSubs = stats['totalSubmissions'] ?? 0;
    final accuracy = ((stats['accuracyRate'] ?? 0) * 100).toStringAsFixed(1);
    final stake = (stats['stakeAmount'] ?? 0).toStringAsFixed(0);
    final rewardsEarned = (stats['rewardsEarned'] ?? 0).toStringAsFixed(0);
    final reputation = stats['reputationScore'] ?? 0;

    return RefreshIndicator(
      onRefresh: () => prov.loadDashboardData(),
      child: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prov.verifier?.organizationName ?? 'Verifier',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _chip(prov.verifier?.organizationType ?? '—', Colors.white24),
                            const SizedBox(width: 8),
                            _chip('⭐ $reputation', Colors.white24),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: const Text('Verifier Dashboard'),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Stats grid ───────────────────────────────────
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    VerifierStatsCard(
                      title: 'Submissions',
                      value: '$totalSubs',
                      icon: Icons.upload_file,
                      color: Colors.blue,
                    ),
                    VerifierStatsCard(
                      title: 'Accuracy',
                      value: '$accuracy%',
                      icon: Icons.verified,
                      color: Colors.green,
                    ),
                    VerifierStatsCard(
                      title: 'Staked',
                      value: '$stake AYT',
                      icon: Icons.lock,
                      color: Colors.orange,
                    ),
                    VerifierStatsCard(
                      title: 'Rewards',
                      value: '$rewardsEarned AYT',
                      icon: Icons.redeem,
                      color: Colors.purple,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Quick actions ────────────────────────────────
                const Text('Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _actionCard(context, 'Submit\nReport', Icons.add_circle, Colors.green,
                        () => _goTab(context, 1)),
                    const SizedBox(width: 12),
                    _actionCard(context, 'View\nHistory', Icons.history, Colors.blue,
                        () => _goTab(context, 2)),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Pending assets ───────────────────────────────
                if (prov.pendingAssets.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pending Assets',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () => _goTab(context, 1),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < prov.pendingAssets.length && i < 3; i++)
                    AssetCard(
                      asset: prov.pendingAssets[i],
                      onSubmit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SubmitReportScreen(asset: prov.pendingAssets[i]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                // ── Recent submissions ───────────────────────────
                if (prov.recentSubmissions.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Submissions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () => _goTab(context, 2),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final sub in prov.recentSubmissions.take(3))
                    SubmissionCard(submission: sub),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _goTab(BuildContext context, int index) {
    // Find the _VerifierDashboardState and switch tab
    final state = context.findAncestorStateOfType<_VerifierDashboardState>();
    state?.setState(() => state._navIndex = index);
  }

  Widget _chip(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _actionCard(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
