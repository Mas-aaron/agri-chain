import 'package:flutter/material.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Profile'),
            subtitle: Text('Coming soon'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.language_outlined),
            title: Text('Language'),
            subtitle: Text('Coming soon'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text('Theme'),
            subtitle: Text('Coming soon'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Data & privacy'),
            subtitle: Text('Coming soon'),
          ),
        ),
      ],
    );
  }
}
