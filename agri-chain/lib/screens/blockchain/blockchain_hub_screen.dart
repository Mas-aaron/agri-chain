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
          const ImageHeroCard(
            imageUrl: 'https://picsum.photos/seed/agrichain_market/1200/700',
            title: 'Agri‑Market',
            subtitle: 'Create, buy, and track Future Harvest Contracts.',
          ),
          const SizedBox(height: 12),
          ImageFeatureCard(
            imageUrl: 'https://picsum.photos/seed/agrichain_contracts/400/400',
            title: 'Future Harvest Contracts',
            subtitle: 'Browse listed harvest predictions and purchase securely.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContractsScreen()),
            ),
          ),
          const SizedBox(height: 10),
          ImageFeatureCard(
            imageUrl: 'https://picsum.photos/seed/agrichain_ledger/400/400',
            title: 'Ledger',
            subtitle: 'Immutable event log for contract lifecycle actions.',
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
