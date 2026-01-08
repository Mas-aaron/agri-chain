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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Fields',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
