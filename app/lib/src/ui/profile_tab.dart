import 'package:flutter/material.dart';

import 'theme.dart';

/// Profil tabı — ayarlar, "AI nəyi öyrənib", rutin öyrənmə naviqasiyası.
/// Aşağıda kiçik "Developer" bölməsi (test bildirişi). Bütün hərəkətlər callback
/// kimi verilir (main.dart bağlayır) — tab decoupled və testlənəndir.
class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.onOpenSettings,
    required this.onOpenLearned,
    required this.onOpenRoutine,
    required this.onTestNotification,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLearned;
  final VoidCallback onOpenRoutine;
  final VoidCallback onTestNotification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        children: [
          _Item(
            icon: Icons.settings_outlined,
            title: 'Ayarlar',
            subtitle: 'Oyanma/yatma vaxtı, bildiriş sayı',
            onTap: onOpenSettings,
          ),
          _Item(
            icon: Icons.insights_outlined,
            title: 'AI nəyi öyrənib',
            subtitle: 'Tez-tez getdiyin yerlər',
            onTap: onOpenLearned,
          ),
          _Item(
            icon: Icons.explore_outlined,
            title: 'Rutin öyrənmə',
            subtitle: 'Arxa fon məkan icazəsi',
            onTap: onOpenRoutine,
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, 16, 8),
            child: Text('Developer',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
          _Item(
            icon: Icons.notifications_active_outlined,
            title: 'Test bildirişi',
            subtitle: 'Bildiriş→kart axınını yoxla',
            onTap: onTestNotification,
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screen, vertical: 4),
      // Ana səhifədəki paket kartları ilə eyni ikon plitəsi (vahid görünüş).
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        ),
        child:
            Icon(icon, color: theme.colorScheme.onSecondaryContainer, size: 20),
      ),
      title: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing:
          Icon(Icons.chevron_right, color: theme.colorScheme.outlineVariant),
      onTap: onTap,
    );
  }
}
