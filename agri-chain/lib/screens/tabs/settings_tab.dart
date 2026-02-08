import 'package:flutter/material.dart';

import 'package:agri_chain/widgets/modern_ui.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ImageHeroCard(
          imageUrl: 'https://picsum.photos/seed/agrichain_settings/1200/700',
          title: 'Settings',
          subtitle: 'Manage your profile, preferences, and app configuration.',
        ),
        const SizedBox(height: 12),
        const FeatureCard(
          icon: Icons.person_outline,
          title: 'Profile',
          subtitle: 'Coming soon',
        ),
        const SizedBox(height: 10),
        const FeatureCard(
          icon: Icons.language_outlined,
          title: 'Language',
          subtitle: 'Coming soon',
        ),
        const SizedBox(height: 10),
        const FeatureCard(
          icon: Icons.dark_mode_outlined,
          title: 'Theme',
          subtitle: 'Coming soon',
        ),
        const SizedBox(height: 10),
        const FeatureCard(
          icon: Icons.privacy_tip_outlined,
          title: 'Data & privacy',
          subtitle: 'Coming soon',
        ),
      ],
    );
  }
}
