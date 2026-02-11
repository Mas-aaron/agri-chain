import 'package:flutter/material.dart';

import 'package:agri_chain/screens/blockchain/contracts_screen.dart';
import 'package:agri_chain/screens/blockchain/ledger_screen.dart';
import 'package:agri_chain/features/blockchain/screens/blockchain_tab.dart';
import 'package:agri_chain/features/blockchain/screens/wallet_screen.dart';
import 'package:agri_chain/features/blockchain/screens/tokenize_yield_screen.dart';
import 'package:agri_chain/features/blockchain/screens/transfer_management_screen.dart';
import 'package:agri_chain/features/blockchain/screens/transaction_screen.dart';
import 'package:agri_chain/features/blockchain/screens/advanced_tokenization_screen.dart';
import 'package:agri_chain/features/blockchain/screens/blockchain_test_screen.dart';
import 'package:agri_chain/config/app_config.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class BlockchainHubScreen extends StatelessWidget {
  const BlockchainHubScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _entry({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return FeatureCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

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
            assetPath: 'assets/images/logo.png',
            title: 'Agri‑Market',
            subtitle: 'Create, buy, and track Future Harvest Contracts.',
          ),
          _section(context, 'Market'),
          _entry(
            context: context,
            icon: Icons.storefront_outlined,
            title: 'Future Harvest Contracts',
            subtitle: 'Browse listings, purchase, and deliver.',
            onTap: () => _push(context, const ContractsScreen()),
          ),
          const SizedBox(height: 10),
          _entry(
            context: context,
            icon: Icons.receipt_long_outlined,
            title: 'Ledger',
            subtitle: 'Immutable event log for contract actions.',
            onTap: () => _push(context, const LedgerScreen()),
          ),

          _section(context, 'Wallet & Tokens'),
          _entry(
            context: context,
            icon: Icons.dashboard_outlined,
            title: 'Portfolio & Tools',
            subtitle: 'All-in-one blockchain tab (portfolio, wallet, tokenize, transfers, etc.).',
            onTap: () => _push(
              context,
              Scaffold(
                appBar: AppBar(title: const Text('Portfolio & Tools')),
                body: const BlockchainTab(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _entry(
            context: context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Wallet',
            subtitle: 'Create/connect a wallet and view balance.',
            onTap: () => _push(context, const WalletScreen()),
          ),
          const SizedBox(height: 10),
          _entry(
            context: context,
            icon: Icons.token,
            title: 'Tokenize Yield',
            subtitle: 'Create a yield token on-chain.',
            onTap: () => _push(context, const TokenizeYieldScreen()),
          ),
          const SizedBox(height: 10),
          _entry(
            context: context,
            icon: Icons.swap_horiz,
            title: 'Transfer Management',
            subtitle: 'Phase-based restrictions and validations.',
            onTap: () => _push(context, const TransferManagementScreen()),
          ),
          const SizedBox(height: 10),
          _entry(
            context: context,
            icon: Icons.send,
            title: 'Send Transaction',
            subtitle: 'Send a raw transaction (demo).',
            onTap: () => _push(context, const TransactionScreen()),
          ),
          const SizedBox(height: 10),
          _entry(
            context: context,
            icon: Icons.security,
            title: 'Advanced Tokenization',
            subtitle: 'Insurance tier + risk controls for transferable tokens.',
            onTap: () => _push(context, const AdvancedTokenizationScreen()),
          ),
          if (AppConfig.isDebugMode) ...[
            _section(context, 'Developer'),
            _entry(
              context: context,
              icon: Icons.bug_report_outlined,
              title: 'Blockchain Tests',
              subtitle: 'Run local integration tests and diagnostics.',
              onTap: () => _push(context, const BlockchainTestScreen()),
            ),
          ],
        ],
      ),
    );
  }
}
