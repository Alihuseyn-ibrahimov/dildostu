import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';
import 'brand.dart';

/// Aşağı naviqasiyalı əsas qabıq — 4 tab. Duolingo tipli qalın ikonlar,
/// LachinGo qızıl seçici vurğusu.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.home,
    required this.chat,
    required this.progress,
    required this.profile,
  });

  final Widget home;
  final Widget chat;
  final Widget progress;
  final Widget profile;

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _index = 0;

  /// Chat tabına keçir (bildiriş deep link).
  void openChatTab() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          widget.home,
          widget.chat,
          widget.progress,
          widget.profile,
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: BrandColors.navy.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: s.tabHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: const Icon(Icons.chat_bubble_rounded),
              label: s.tabChat,
            ),
            NavigationDestination(
              icon: const Icon(Icons.flight_takeoff_outlined),
              selectedIcon: const Icon(Icons.flight_takeoff_rounded),
              label: s.tabProgress,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: s.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}
