import 'package:flutter/material.dart';
import 'package:agri_chain/home_screen.dart';
import 'package:agri_chain/screens/tabs/alerts_tab.dart';
import 'package:agri_chain/screens/tabs/dashboard_tab.dart';
import 'package:agri_chain/screens/tabs/fields_tab.dart';
import 'package:agri_chain/screens/tabs/settings_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const DashboardTab(),
      const HomeScreen(embedded: true),
      const FieldsTab(),
      const AlertsTab(),
      const SettingsTab(),
    ];

    final titles = <String>[
      'Dashboard',
      'Scan',
      'Fields',
      'Alerts',
      'Settings',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
      ),
      body: IndexedStack(
        index: _index,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Fields',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
