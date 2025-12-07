import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/router_service.dart';

/// Main scaffold with bottom navigation and FAB
class MainScaffold extends StatefulWidget {
  final Widget child;

  const MainScaffold({
    super.key,
    required this.child,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.receipts)) return 0;
    if (location.startsWith(AppRoutes.reports)) return 1;
    if (location.startsWith(AppRoutes.account)) return 2;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.receipts);
        break;
      case 1:
        context.go(AppRoutes.reports);
        break;
      case 2:
        context.go(AppRoutes.account);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final showFab = selectedIndex == 0 || selectedIndex == 1;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Receipts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.capture),
              child: const Icon(Icons.camera_alt),
            )
          : null,
    );
  }
}
