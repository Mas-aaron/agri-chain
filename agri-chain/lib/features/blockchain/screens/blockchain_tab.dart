import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/config/app_config.dart';
import '../providers/blockchain_provider.dart';
import 'yield_details_screen.dart';
import 'wallet_screen.dart';
import 'tokenize_yield_screen.dart';
import 'transaction_screen.dart';
import 'blockchain_test_screen.dart';
import 'advanced_tokenization_screen.dart';
import 'transfer_management_screen.dart';
import '../widgets/asset_card.dart';
import '../widgets/portfolio_summary.dart';

/// Main blockchain/yield tab screen
class BlockchainTab extends StatefulWidget {
  const BlockchainTab({super.key});

  @override
  State<BlockchainTab> createState() => _BlockchainTabState();
}

class _BlockchainTabState extends State<BlockchainTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final tabCount = AppConfig.isDebugMode ? 7 : 6;
    _tabController = TabController(length: tabCount, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BlockchainProvider>();
      // Initialize blockchain connection
      provider.initializeBlockchain();
      // Initialize with a default farmer ID (should come from auth in production)
      if (provider.selectedFarmerId == null) {
        provider.initialize('FARMER_001');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BlockchainProvider>(
      builder: (context, blockchainProvider, _) {
        return Column(
          children: [
            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(icon: Icon(Icons.dashboard), text: 'Portfolio'),
                const Tab(icon: Icon(Icons.wallet), text: 'Wallet'),
                const Tab(icon: Icon(Icons.token), text: 'Tokenize'),
                const Tab(icon: Icon(Icons.swap_horiz), text: 'Transfers'),
                const Tab(icon: Icon(Icons.send), text: 'Transactions'),
                const Tab(icon: Icon(Icons.security), text: 'Advanced'),
                if (AppConfig.isDebugMode) const Tab(icon: Icon(Icons.bug_report), text: 'Tests'),
              ],
            ),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPortfolioTab(blockchainProvider),
                  const WalletScreen(),
                  const TokenizeYieldScreen(),
                  const TransferManagementScreen(),
                  const TransactionScreen(),
                  const AdvancedTokenizationScreen(),
                  if (AppConfig.isDebugMode)
                    const BlockchainTestScreen(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPortfolioTab(BlockchainProvider blockchainProvider) {
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
              // Wallet Status
              _buildWalletStatus(blockchainProvider),
              const SizedBox(height: 24),

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
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            _tabController.animateTo(2); // Navigate to Tokenize tab
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Yield Asset'),
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
  }

  Widget _buildWalletStatus(BlockchainProvider blockchainProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blockchainProvider.isWalletConnected 
            ? Colors.green.shade50 
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: blockchainProvider.isWalletConnected 
              ? Colors.green.shade200 
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            blockchainProvider.isWalletConnected 
                ? Icons.check_circle 
                : Icons.warning,
            color: blockchainProvider.isWalletConnected 
                ? Colors.green.shade600 
                : Colors.orange.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blockchainProvider.isWalletConnected 
                      ? 'Wallet Connected' 
                      : 'Wallet Not Connected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: blockchainProvider.isWalletConnected 
                        ? Colors.green.shade800 
                        : Colors.orange.shade800,
                  ),
                ),
                Text(
                  blockchainProvider.isWalletConnected 
                      ? 'Address: ${blockchainProvider.walletAddress?.substring(0, 10) ?? ''}...'
                      : 'Connect your wallet to access blockchain features',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: blockchainProvider.isWalletConnected 
                        ? Colors.green.shade700 
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (!blockchainProvider.isWalletConnected)
            TextButton(
              onPressed: () {
                _tabController.animateTo(1); // Navigate to Wallet tab
              },
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
}
