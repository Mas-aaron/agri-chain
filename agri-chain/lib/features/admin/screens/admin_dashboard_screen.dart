import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'agrochemicals_screen.dart';
import 'suppliers_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Admin dashboard',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text('Signed in as: ${email ?? 'Unknown'}'),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Suppliers'),
            subtitle: const Text('Register and manage accredited suppliers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SuppliersScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Agrochemicals'),
            subtitle: const Text('Register and link credited agrochemicals'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgrochemicalsScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}
