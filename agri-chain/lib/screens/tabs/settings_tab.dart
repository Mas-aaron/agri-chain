import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agri_chain/widgets/modern_ui.dart';
import 'package:agri_chain/features/admin/screens/admin_entry_screen.dart';
import 'package:agri_chain/services/auth_service.dart';
import 'package:agri_chain/screens/profile_screen.dart';
import 'package:agri_chain/providers/locale_provider.dart';
import 'package:agri_chain/l10n/app_strings.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final currentLang = localeProvider.languageLabel;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ImageHeroCard(
          imageUrl: 'https://source.unsplash.com/1200x700/?maize,farm,technology',
          title: 'Settings',
          subtitle: 'Manage your profile, preferences, and app configuration.',
        ),
        const SizedBox(height: 12),
        FeatureCard(
          icon: Icons.person_outline,
          title: s.profile,
          subtitle: s.profileSubtitle,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        FeatureCard(
          icon: Icons.language_outlined,
          title: s.language,
          subtitle: currentLang,
          onTap: () => _showLanguagePicker(context, s),
        ),
        const SizedBox(height: 10),
        FeatureCard(
          icon: Icons.dark_mode_outlined,
          title: s.theme,
          subtitle: Theme.of(context).brightness == Brightness.dark ? s.darkMode : s.lightMode,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Theme toggle coming soon')),
            );
          },
        ),
        const SizedBox(height: 10),
        FeatureCard(
          icon: Icons.admin_panel_settings_outlined,
          title: s.admin,
          subtitle: s.adminSubtitle,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminEntryScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        FeatureCard(
          icon: Icons.logout_outlined,
          title: s.signOut,
          subtitle: s.signOutSubtitle,
          onTap: () async {
            await context.read<AuthService>().signOut();
          },
        ),
      ],
    );
  }

  void _showLanguagePicker(BuildContext context, AppStrings s) {
    final localeProvider = context.read<LocaleProvider>();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.translate, color: Theme.of(ctx).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        s.selectLanguage,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      ...LocaleProvider.supportedLocales.entries.map((entry) {
                        final isSelected = localeProvider.currentCode == entry.key;
                        return ListTile(
                          leading: isSelected
                              ? Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary)
                              : const Icon(Icons.circle_outlined),
                          title: Text(entry.value),
                          onTap: () {
                            localeProvider.setLocale(entry.key);
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
