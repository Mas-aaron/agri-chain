import 'package:flutter/material.dart';

import 'package:agri_chain/screens/blockchain/contracts_screen.dart';
import 'package:agri_chain/screens/blockchain/ledger_screen.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class BlockchainHubScreen extends StatelessWidget {
  const BlockchainHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blockchain'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GradientHeroCard(
            icon: Icons.hub_outlined,
            title: 'Agri‑Market',
            subtitle: 'Tokenize predicted yield into on‑chain contracts (simulation).',
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.description_outlined,
            title: 'Future Harvest Contracts',
            subtitle: 'Browse and manage contracts (demo)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContractsScreen()),
            ),
          ),
          const SizedBox(height: 10),
          FeatureCard(
            icon: Icons.history,
            title: 'Ledger',
            subtitle: 'Immutable event log (demo)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LedgerScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
