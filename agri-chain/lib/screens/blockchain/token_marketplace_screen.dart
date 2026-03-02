import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:agri_chain/config/app_config.dart';
import 'package:agri_chain/services/contracts_api_service.dart';
import 'package:agri_chain/screens/blockchain/loan_application_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Token Model ─────────────────────────────────────────────

class TokenAsset {
  final String assetId;
  final String tokenId;
  final String farmerId;
  final String cropType;
  final int season;
  final double predictedYield;
  final double confidence;
  final double tokenAmount;
  final String tokenSymbol;
  final String tokenStandard;
  final double currentValue;
  final String status;
  final bool collateralized;
  final String source;
  final String? txStatus;
  final String createdAt;

  TokenAsset({
    required this.assetId,
    required this.tokenId,
    required this.farmerId,
    required this.cropType,
    required this.season,
    required this.predictedYield,
    required this.confidence,
    required this.tokenAmount,
    required this.tokenSymbol,
    required this.tokenStandard,
    required this.currentValue,
    required this.status,
    required this.collateralized,
    required this.source,
    this.txStatus,
    required this.createdAt,
  });

  factory TokenAsset.fromJson(Map<String, dynamic> j) {
    return TokenAsset(
      assetId: (j['assetId'] ?? '').toString(),
      tokenId: (j['tokenId'] ?? '').toString(),
      farmerId: (j['farmerId'] ?? '').toString(),
      cropType: (j['cropType'] ?? 'Maize').toString(),
      season: (j['season'] is num) ? (j['season'] as num).toInt() : 2026,
      predictedYield: _toDouble(j['predictedYield']),
      confidence: _toDouble(j['confidence']),
      tokenAmount: _toDouble(j['tokenAmount']),
      tokenSymbol: (j['tokenSymbol'] ?? '').toString(),
      tokenStandard: (j['tokenStandard'] ?? 'ERC-1155').toString(),
      currentValue: _toDouble(j['currentValue']),
      status: (j['status'] ?? 'PREDICTED').toString(),
      collateralized: j['collateralized'] == true,
      source: (j['source'] ?? 'mock').toString(),
      txStatus: j['txStatus']?.toString(),
      createdAt: (j['createdAt'] ?? '').toString(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  int get daysToMaturity {
    // Estimate maturity: season harvest is ~December
    final harvestDate = DateTime(season, 12, 1);
    return harvestDate.difference(DateTime.now()).inDays.clamp(0, 999);
  }

  String get qualityGrade {
    if (confidence >= 0.9) return 'A+';
    if (confidence >= 0.8) return 'A';
    if (confidence >= 0.7) return 'B+';
    if (confidence >= 0.6) return 'B';
    return 'C';
  }

  bool get isOnChain => source == 'blockchain';
}

// ─── Token Marketplace Screen ────────────────────────────────

class TokenMarketplaceScreen extends StatefulWidget {
  final VoidCallback? onNavigateToContracts;

  const TokenMarketplaceScreen({super.key, this.onNavigateToContracts});

  @override
  State<TokenMarketplaceScreen> createState() => _TokenMarketplaceScreenState();
}

class _TokenMarketplaceScreenState extends State<TokenMarketplaceScreen> {
  late Future<List<TokenAsset>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchTokens();
  }

  Future<List<TokenAsset>> _fetchTokens() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/blockchain/assets');
    final resp = await http.get(uri, headers: {'Content-Type': 'application/json'});
    if (resp.statusCode >= 400) {
      throw Exception('Failed to load tokens (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return [];
    return decoded.map((e) => TokenAsset.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _reload() => setState(() => _future = _fetchTokens());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Marketplace'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload, tooltip: 'Refresh'),
        ],
      ),
      body: FutureBuilder<List<TokenAsset>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 12),
                  Text('Error: ${snap.error}', style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final tokens = snap.data ?? [];
          if (tokens.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.token_outlined, size: 64, color: scheme.onSurfaceVariant.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No tokens yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use Yield Forecast to predict & tokenize a harvest.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          if (isWide) {
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 480,
                mainAxisExtent: 520,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: tokens.length,
              itemBuilder: (ctx, i) => _TokenCard(token: tokens[i], onSign: () => _showSignDialog(tokens[i])),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tokens.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _TokenCard(token: tokens[i], onSign: () => _showSignDialog(tokens[i])),
            ),
          );
        },
      ),
    );
  }

  void _showSignDialog(TokenAsset token) {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to sign a contract.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final orgController = TextEditingController(text: 'AgriFinance Ltd.');

    showDialog(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Icon(Icons.draw_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              const Text('Sign Contract'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.token, color: scheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${token.tokenId} • ${token.predictedYield.toStringAsFixed(0)} kg ${token.cropType}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orgController,
                  decoration: const InputDecoration(
                    labelText: 'Organization',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'By signing, you agree to the terms of this yield-backed contract. '
                        'This will be recorded on the Hyperledger Fabric ledger.',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () async {
                final buyerName = nameController.text.trim();
                if (buyerName.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter your name')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                if (!mounted) return;

                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Text('Creating contract for ${token.tokenId}...'),
                      ],
                    ),
                    duration: const Duration(seconds: 10),
                  ),
                );

                // Create a contract from the token
                try {
                  final api = ContractsApiService.fromBaseUrl(AppConfig.apiBaseUrl);
                  await api.createContract(ContractCreateRequest(
                    crop: token.cropType,
                    quantityKg: token.predictedYield,
                    unitPrice: token.currentValue / token.predictedYield,
                    currency: 'USD',
                    farmerName: token.farmerId,
                    evidenceHash: token.assetId,
                  ));

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Contract signed for ${token.tokenId}! '
                              'Navigating to Contracts...',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  // Navigate to Contracts screen
                  if (widget.onNavigateToContracts != null) {
                    widget.onNavigateToContracts!();
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating contract: $e'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.draw),
              label: const Text('Sign & Submit'),
            ),
          ],
        );
      },
    );
  }
}

// ─── Token Card ──────────────────────────────────────────────

class _TokenCard extends StatelessWidget {
  final TokenAsset token;
  final VoidCallback onSign;

  const _TokenCard({required this.token, required this.onSign});

  Future<void> _openExplorer(BuildContext context) async {
    final url = Uri.parse(
        '${AppConfig.explorerBaseUrl}/assets/${token.assetId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open blockchain explorer')),
      );
    }
  }

  void _openLoanScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoanApplicationScreen(token: token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final statusColor = switch (token.status.toUpperCase()) {
      'PREDICTED' => Colors.blue,
      'LISTED' => Colors.orange,
      'PURCHASED' => Colors.green,
      'COLLATERALIZED' => Colors.purple,
      _ => Colors.grey,
    };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withOpacity(0.08),
                  scheme.primary.withOpacity(0.02),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.token, color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.tokenId,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Asset: ${token.assetId}',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    token.status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
          ),

          // ── Data Grid ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  // Row 1: Crop & Yield
                  Row(
                    children: [
                      Expanded(child: _DataCell(label: 'Crop', value: token.cropType, icon: Icons.grass)),
                      Expanded(
                        child: _DataCell(
                          label: 'Predicted Yield',
                          value: '${token.predictedYield.toStringAsFixed(0)} kg',
                          icon: Icons.scale,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 2: Quality & Days to Maturity
                  Row(
                    children: [
                      Expanded(
                        child: _DataCell(
                          label: 'Quality Grade',
                          value: token.qualityGrade,
                          icon: Icons.verified,
                          valueColor: token.qualityGrade.startsWith('A') ? Colors.green : Colors.orange,
                        ),
                      ),
                      Expanded(
                        child: _DataCell(
                          label: 'Days to Maturity',
                          value: '${token.daysToMaturity} days',
                          icon: Icons.calendar_today,
                          valueColor: token.daysToMaturity < 60 ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 3: Tokens & Value
                  Row(
                    children: [
                      Expanded(
                        child: _DataCell(
                          label: 'Token Amount',
                          value: token.tokenAmount.toStringAsFixed(1),
                          icon: Icons.generating_tokens,
                        ),
                      ),
                      Expanded(
                        child: _DataCell(
                          label: 'Current Value',
                          value: '\$${token.currentValue.toStringAsFixed(0)}',
                          icon: Icons.attach_money,
                          valueColor: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 4: Season & Standard
                  Row(
                    children: [
                      Expanded(
                        child: _DataCell(
                          label: 'Season',
                          value: '${token.season}',
                          icon: Icons.event,
                        ),
                      ),
                      Expanded(
                        child: _DataCell(
                          label: 'Standard',
                          value: token.tokenStandard,
                          icon: Icons.code,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // ── Blockchain badge ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: token.isOnChain
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: token.isOnChain
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              token.isOnChain ? Icons.link : Icons.link_off,
                              size: 12,
                              color: token.isOnChain ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              token.isOnChain ? 'On-Chain' : 'Mock',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: token.isOnChain ? Colors.green.shade800 : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (token.farmerId.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Farmer: ${token.farmerId}',
                            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Action Buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSign,
                    icon: const Icon(Icons.draw, size: 18),
                    label: const Text('Sign Contract'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _openExplorer(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.open_in_new, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _DataCell({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.primary.withOpacity(0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
