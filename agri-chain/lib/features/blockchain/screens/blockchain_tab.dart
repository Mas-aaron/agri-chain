import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_provider.dart';
import 'yield_details_screen.dart';
import '../widgets/asset_card.dart';
import '../widgets/portfolio_summary.dart';

/// Main blockchain/yield tab screen
class BlockchainTab extends StatefulWidget {
  const BlockchainTab({super.key});

  @override
  State<BlockchainTab> createState() => _BlockchainTabState();
}

class _BlockchainTabState extends State<BlockchainTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BlockchainProvider>();
      // Initialize with a default farmer ID (should come from auth in production)
      if (provider.selectedFarmerId == null) {
        provider.initialize('FARMER_001');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BlockchainProvider>(
      builder: (context, blockchainProvider, _) {
        if (blockchainProvider.isLoading && blockchainProvider.assets.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return RefreshIndicator(
          onRefresh: () => blockchainProvider.refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Portfolio Summary
                  if (blockchainProvider.hasAssets)
                    PortfolioSummary(
                      totalValue: blockchainProvider.totalPortfolioValue,
                      assetCount: blockchainProvider.assets.length,
                      averageConfidence: blockchainProvider.averageConfidence,
                    ),
                  const SizedBox(height: 24),

                  // Assets List
                  Text(
                    'Yield Assets',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  if (blockchainProvider.hasAssets)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: blockchainProvider.assets.length,
                      itemBuilder: (context, index) {
                        final asset = blockchainProvider.assets[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: AssetCard(
                            asset: asset,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      YieldDetailsScreen(asset: asset),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.agriculture,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No yield assets yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first yield asset to get started',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Error handling
                  if (blockchainProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                blockchainProvider.error!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
