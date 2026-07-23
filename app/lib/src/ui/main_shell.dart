import 'package:flutter/material.dart';

/// Aşağı naviqasiyalı əsas qabıq — 4 tab (Ana səhifə / Söhbət / İrəliləyiş /
/// Profil). `IndexedStack` tabların vəziyyətini saxlayır (keçəndə itmir).
///
/// Tab gövdələri parametr kimi verilir → shell yüngül və test olunandır
/// (məzmun main.dart-da qurulur).
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
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana səhifə',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Söhbət',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'İrəliləyiş',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
