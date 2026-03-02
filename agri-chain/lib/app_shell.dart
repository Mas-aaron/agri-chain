import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agri_chain/home_screen.dart';
import 'package:agri_chain/screens/tabs/alerts_tab.dart';
import 'package:agri_chain/screens/tabs/dashboard_tab.dart';
import 'package:agri_chain/screens/tabs/fields_tab.dart';
import 'package:agri_chain/screens/rover/field_map_screen.dart';
import 'package:agri_chain/screens/tabs/settings_tab.dart';
import 'package:agri_chain/screens/yield_prediction_screen.dart';
import 'package:agri_chain/screens/blockchain/contracts_screen.dart';
import 'package:agri_chain/screens/blockchain/ledger_screen.dart';
import 'package:agri_chain/screens/blockchain/token_marketplace_screen.dart';
import 'package:agri_chain/screens/blockchain/blockchain_hub_screen.dart';
import 'package:agri_chain/screens/blockchain/loans_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // All pages accessible from both mobile and web
  static const _navItems = <_NavItem>[
    _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),        // 0
    _NavItem(icon: Icons.auto_graph_outlined, selectedIcon: Icons.auto_graph, label: 'Yield Forecast'), // 1
    _NavItem(icon: Icons.token_outlined, selectedIcon: Icons.token, label: 'Token Market'),             // 2
    _NavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Contracts'),      // 3
    _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Ledger'),     // 4
    _NavItem(icon: Icons.account_balance_outlined, selectedIcon: Icons.account_balance, label: 'Loans'),// 5
    _NavItem(icon: Icons.camera_alt_outlined, selectedIcon: Icons.camera_alt, label: 'Disease Scan'),   // 6
    _NavItem(icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Fields'),                       // 7
    _NavItem(icon: Icons.notifications_outlined, selectedIcon: Icons.notifications, label: 'Alerts'),   // 8
    _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),           // 9
  ];

  Widget _pageAt(int i) {
    switch (i) {
      case 0:
        return const DashboardTab();
      case 1:
        return const YieldPredictionScreen();
      case 2:
        return TokenMarketplaceScreen(onNavigateToContracts: () => setState(() => _index = 3));
      case 3:
        return ContractsScreen(onNavigateToLedger: () => setState(() => _index = 4));
      case 4:
        return const LedgerScreen();
      case 5:
        return LoansScreen(onNavigateToMarketplace: () => setState(() => _index = 2));
      case 6:
        return const HomeScreen(embedded: true);
      case 7:
        return const FieldMapScreen();
      case 8:
        return const AlertsTab();
      case 9:
        return const SettingsTab();
      default:
        return const DashboardTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    if (isWide) {
      return _WebLayout(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        items: _navItems,
        child: _pageAt(_index),
      );
    }

    // Mobile layout — bottom nav with 4 key tabs
    const mobileIndices = [0, 2, 6, 9]; // Dashboard, Token Market, Scan, Settings
    final mobileIndex = mobileIndices.indexOf(_index).clamp(0, 3);

    return Scaffold(
      body: _pageAt(_index),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndex,
        onDestinationSelected: (i) => setState(() => _index = mobileIndices[i]),
        destinations: [
          for (final idx in mobileIndices)
            NavigationDestination(
              icon: Icon(_navItems[idx].icon),
              selectedIcon: Icon(_navItems[idx].selectedIcon),
              label: _navItems[idx].label,
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({required this.icon, required this.selectedIcon, required this.label});
}

// ─────────────────────────────────────────────────────────────
// Web / Desktop Layout — top navbar + sidebar + content area
// ─────────────────────────────────────────────────────────────
class _WebLayout extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<_NavItem> items;
  final Widget child;

  const _WebLayout({
    required this.index,
    required this.onChanged,
    required this.items,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isExtraWide = width >= 1200;

    return Scaffold(
      body: Column(
        children: [
          // ── Top Navbar ──
          _TopNavbar(
            index: index,
            onChanged: onChanged,
            items: items,
            isExtraWide: isExtraWide,
          ),
          // ── Content ──
          Expanded(
            child: Row(
              children: [
                // Sidebar on very wide screens
                if (isExtraWide)
                  _Sidebar(
                    index: index,
                    onChanged: onChanged,
                    items: items,
                  ),
                // Main content
                Expanded(
                  child: Container(
                    color: scheme.surfaceContainerLowest,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Footer ──
          _Footer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Top Navigation Bar
// ─────────────────────────────────────────────────────────────
class _TopNavbar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<_NavItem> items;
  final bool isExtraWide;

  const _TopNavbar({
    required this.index,
    required this.onChanged,
    required this.items,
    required this.isExtraWide,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.spa_rounded, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            'AgriChain',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'BETA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 32),

          // Nav links (only on medium screens, sidebar takes over on extra-wide)
          if (!isExtraWide)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < items.length; i++)
                      _NavLink(
                        label: items[i].label,
                        icon: items[i].icon,
                        selected: i == index,
                        onTap: () => onChanged(i),
                      ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),

          // Right side — status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'BCS Connected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? scheme.primary.withOpacity(0.1)
                : _hovered
                    ? scheme.onSurface.withOpacity(0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.selected ? widget.icon : widget.icon,
                size: 18,
                color: widget.selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sidebar (extra-wide screens)
// ─────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<_NavItem> items;

  const _Sidebar({
    required this.index,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'NAVIGATION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < items.length; i++)
            _SidebarItem(
              icon: items[i].icon,
              selectedIcon: items[i].selectedIcon,
              label: items[i].label,
              selected: i == index,
              onTap: () => onChanged(i),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.primary.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text('Blockchain', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hyperledger Fabric\nChannel: yieldchannel',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? scheme.primary.withOpacity(0.1)
                : _hovered
                    ? scheme.onSurface.withOpacity(0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                widget.selected ? widget.selectedIcon : widget.icon,
                size: 20,
                color: widget.selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Text(
            '© 2026 AgriChain — AI-Powered Yield Tokenization on Hyperledger Fabric',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            'Huawei Cloud BCS  •  ECS  •  SWR',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
