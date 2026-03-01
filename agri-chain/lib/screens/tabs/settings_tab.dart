import 'package:flutter/material.dart';

import 'package:agri_chain/widgets/modern_ui.dart';
import 'package:agri_chain/features/admin/screens/admin_entry_screen.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/services/auth_service.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ImageHeroCard(
          imageUrl: 'https://source.unsplash.com/1200x700/?maize,farm,technology',
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
        const SizedBox(height: 10),
        const SizedBox(height: 10),
        FeatureCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Admin',
          subtitle: 'Manage suppliers and agrochemicals',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminEntryScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        FeatureCard(
          icon: Icons.logout_outlined,
          title: 'Sign out',
          subtitle: 'Log out of your farm account',
          onTap: () async {
            await context.read<AuthService>().signOut();
          },
        ),
      ],
    );
  }
}
