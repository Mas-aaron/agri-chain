// Full list of assets awaiting verifier yield reports.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/screens/verifier/widgets/asset_card.dart';
import 'package:agri_chain/screens/verifier/submit_report_screen.dart';

class PendingAssetsScreen extends StatelessWidget {
  const PendingAssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<VerifierProvider>();
    final assets = prov.pendingAssets;

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Assets')),
      body: prov.isLoading && assets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : assets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No pending assets',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('All assets have been reviewed.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => prov.loadDashboardData(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: assets.length,
                    itemBuilder: (context, i) => AssetCard(
                      asset: assets[i],
                      onSubmit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubmitReportScreen(asset: assets[i]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
