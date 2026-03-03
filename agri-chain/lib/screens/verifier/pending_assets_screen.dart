import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/widgets/modern_ui.dart';
import 'submit_report_screen.dart';

class PendingAssetsScreen extends StatefulWidget {
  const PendingAssetsScreen({super.key});

  @override
  State<PendingAssetsScreen> createState() => _PendingAssetsScreenState();
}

class _PendingAssetsScreenState extends State<PendingAssetsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VerifierProvider>().loadPendingAssets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prov = context.watch<VerifierProvider>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => prov.loadPendingAssets(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(
              title: 'Pending Assets',
              subtitle: 'Assets awaiting your yield verification report',
            ),
            const SizedBox(height: 16),

            if (prov.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (prov.pendingAssets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 56, color: scheme.primary.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'All caught up!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No assets are pending verification right now.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else
              for (final asset in prov.pendingAssets) ...[
                _AssetTile(asset: asset),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final Map<String, dynamic> asset;
  const _AssetTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FeatureCard(
      icon: Icons.grass,
      title: asset['asset_id'] ?? 'Unknown Asset',
      subtitle: '${asset['crop_type'] ?? 'Maize'} \u2022 Season ${asset['season'] ?? '-'}',
      iconColor: Colors.orange,
      trailing: FilledButton.tonal(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubmitReportScreen(asset: asset),
            ),
          );
        },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Verify', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubmitReportScreen(asset: asset),
          ),
        );
      },
    );
  }
}
