import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/widgets/modern_ui.dart';
import 'pending_assets_screen.dart';
import 'submission_history_screen.dart';
import 'verifier_stake_screen.dart';
import 'verifier_profile_screen.dart';

class VerifierDashboard extends StatefulWidget {
  const VerifierDashboard({super.key});

  @override
  State<VerifierDashboard> createState() => _VerifierDashboardState();
}

class _VerifierDashboardState extends State<VerifierDashboard> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VerifierProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final pages = [
      const _DashboardHome(),
      const PendingAssetsScreen(),
      const SubmissionHistoryScreen(),
      const VerifierStakeScreen(),
      const VerifierProfileScreen(),
    ];

    return Scaffold(
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Pending',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outlined),
            selectedIcon: Icon(Icons.lock),
            label: 'Stake',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Dashboard Home Tab
// ─────────────────────────────────────────────────────────────
class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prov = context.watch<VerifierProvider>();
    final stats = prov.dashboardStats;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => prov.loadDashboardData(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Header ──────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.verified_user, size: 24, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verifier Portal',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        'Independent yield verification',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Logout button
                IconButton(
                  onPressed: () => _showLogoutDialog(context),
                  icon: Icon(Icons.logout, color: scheme.onSurfaceVariant),
                  tooltip: 'Sign out',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Hero card ───────────────────────────────────
            GradientHeroCard(
              icon: Icons.verified,
              title: 'Verification Hub',
              subtitle: 'Submit yield reports, stake tokens, and earn rewards for accurate data.',
            ),
            const SizedBox(height: 20),

            // ── Stats Grid ──────────────────────────────────
            if (prov.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              const SectionHeader(title: 'Your Stats'),
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
                    label: 'Submissions',
                    value: '${stats['totalSubmissions'] ?? 0}',
                    icon: Icons.assignment_turned_in,
                  ),
                  MiniStatTile(
                    label: 'Accuracy',
                    value: '${((stats['accuracyRate'] ?? 0.0) * 100).toStringAsFixed(0)}%',
                    icon: Icons.track_changes,
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

              // ── Quick Actions ─────────────────────────────
              const SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 12),
              FeatureCard(
                icon: Icons.assignment_outlined,
                title: 'Pending Assets',
                subtitle: '${stats['pendingAssetsCount'] ?? 0} assets awaiting verification',
                onTap: () {
                  // Find the parent _VerifierDashboardState and switch tab
                  final dashState = context.findAncestorStateOfType<_VerifierDashboardState>();
                  dashState?.setState(() => dashState._tabIndex = 1);
                },
              ),
              const SizedBox(height: 10),
              FeatureCard(
                icon: Icons.lock_outlined,
                title: 'Manage Stake',
                subtitle: 'Stake tokens to increase your verification weight',
                iconColor: Colors.orange,
                onTap: () {
                  final dashState = context.findAncestorStateOfType<_VerifierDashboardState>();
                  dashState?.setState(() => dashState._tabIndex = 3);
                },
              ),
              const SizedBox(height: 10),
              FeatureCard(
                icon: Icons.history_outlined,
                title: 'Submission History',
                subtitle: 'View your past yield reports and their status',
                iconColor: Colors.blue,
                onTap: () {
                  final dashState = context.findAncestorStateOfType<_VerifierDashboardState>();
                  dashState?.setState(() => dashState._tabIndex = 2);
                },
              ),
              const SizedBox(height: 24),

              // ── Reputation badge ──────────────────────────
              ModernCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _reputationColor(stats['reputationScore'] ?? 500).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.star,
                        color: _reputationColor(stats['reputationScore'] ?? 500),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stats['reputationScore'] ?? 500} Reputation',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _reputationTier(stats['reputationScore'] ?? 500),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (stats['isActive'] == true ? Colors.green : Colors.red).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        stats['isActive'] == true ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: stats['isActive'] == true ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _reputationColor(int score) {
    if (score >= 900) return Colors.purple;
    if (score >= 800) return Colors.amber.shade700;
    if (score >= 700) return Colors.grey.shade600;
    if (score >= 600) return Colors.brown;
    return Colors.grey;
  }

  static String _reputationTier(int score) {
    if (score >= 900) return 'Platinum Tier';
    if (score >= 800) return 'Gold Tier';
    if (score >= 700) return 'Silver Tier';
    if (score >= 600) return 'Bronze Tier';
    return 'New Verifier';
  }

  static void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of the verifier portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
