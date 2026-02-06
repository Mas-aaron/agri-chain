import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/yield_asset.dart';
import '../../config/theme.dart';

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({Key? key}) : super(key: key);

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  List<YieldAsset> assets = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // Mock data - replace with API call
      final mockAssets = [
        YieldAsset(
          assetId: "ASSET_2024_WHEAT_001",
          tokenId: "AYW-2024-WHEAT-001",
          farmerId: "FARMER_001",
          cropType: "Wheat",
          season: 2024,
          predictedYield: 5000,
          confidence: 0.85,
          tokenAmount: 5000,
          currentValue: 25000,
          status: "PREDICTED",
        ),
        YieldAsset(
          assetId: "ASSET_2024_CORN_001",
          tokenId: "AYC-2024-CORN-001",
          farmerId: "FARMER_001",
          cropType: "Corn",
          season: 2024,
          predictedYield: 3500,
          confidence: 0.78,
          tokenAmount: 3500,
          currentValue: 17500,
          status: "PREDICTED",
        ),
      ];
      setState(() => assets = mockAssets);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  double get totalTokens =>
      assets.fold(0, (sum, asset) => sum + asset.tokenAmount);
  double get totalValue =>
      assets.fold(0, (sum, asset) => sum + asset.currentValue);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriYield Farmer Portal'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    _buildHeaderSection(context),
                    const SizedBox(height: 24),

                    // Key Stats
                    _buildStatsSection(context),
                    const SizedBox(height: 24),

                    // Yield Distribution Chart
                    _buildChartSection(context),
                    const SizedBox(height: 24),

                    // Assets List
                    _buildAssetsSection(context),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to tokenize yield
        },
        label: const Text('Tokenize Yield'),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🌾 Welcome Back, Farmer',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tokenize, trade, and secure loans with your yield predictions',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          context,
          title: 'Total Tokens',
          value: '${totalTokens.toStringAsFixed(0)}',
          subtitle: 'AYT',
          icon: Icons.agriculture,
          color: AppTheme.primaryGreen,
        ),
        _buildStatCard(
          context,
          title: 'Total Value',
          value: '\$${(totalValue / 1000).toStringAsFixed(1)}K',
          subtitle: 'USD',
          icon: Icons.attach_money,
          color: AppTheme.accentOrange,
        ),
        _buildStatCard(
          context,
          title: 'Avg Confidence',
          value:
              '${(assets.isNotEmpty ? (assets.map((e) => e.confidence).reduce((a, b) => a + b) / assets.length * 100) : 0).toStringAsFixed(0)}%',
          subtitle: 'ML Model',
          icon: Icons.trending_up,
          color: AppTheme.accentBlue,
        ),
        _buildStatCard(
          context,
          title: 'Active Assets',
          value: '${assets.length}',
          subtitle: 'Items',
          icon: Icons.inventory_2,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yield Distribution',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: assets.isEmpty
                  ? const Center(
                      child: Text('No data available'),
                    )
                  : PieChart(
                      PieChartData(
                        sections: assets
                            .asMap()
                            .entries
                            .map((e) => PieChartSectionData(
                                  color: [
                                    AppTheme.primaryGreen,
                                    AppTheme.accentOrange,
                                    AppTheme.accentBlue,
                                  ][e.key % 3],
                                  value: e.value.tokenAmount,
                                  title: e.value.cropType,
                                  radius: 100,
                                ))
                            .toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Yield Assets',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ...assets.map((asset) => _buildAssetCard(context, asset)).toList(),
      ],
    );
  }

  Widget _buildAssetCard(BuildContext context, YieldAsset asset) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.cropType,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Token: ${asset.tokenId}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
                Chip(
                  label: Text(asset.status),
                  backgroundColor: asset.status == 'PREDICTED'
                      ? AppTheme.accentBlue.withOpacity(0.2)
                      : AppTheme.primaryGreen.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: asset.status == 'PREDICTED'
                        ? AppTheme.accentBlue
                        : AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Predicted Yield',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    Text(
                      '${asset.predictedYield.toStringAsFixed(0)} units',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Current Value',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    Text(
                      '\$${asset.currentValue.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: asset.confidence,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  asset.confidence > 0.8 ? Colors.green : AppTheme.accentOrange,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(asset.confidence * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.visibility),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.trending_up),
                    label: const Text('Trade'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
