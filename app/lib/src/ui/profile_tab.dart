import 'package:flutter/material.dart';

import 'theme.dart';

/// Profil tabı — ayarlar, "AI nəyi öyrənib", rutin öyrənmə naviqasiyası, hesab
/// idarəetməsi (çıxış/silmə) və kiçik "Developer" bölməsi. Bütün hərəkətlər
/// callback kimi verilir (main.dart bağlayır) — tab decoupled və testlənəndir.
class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.onOpenSettings,
    required this.onOpenLearned,
    required this.onOpenRoutine,
    required this.onTestNotification,
    required this.email,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLearned;

  /// Rutin öyrənmə (arxa fon məkan) giriş nöqtəsi. `null`-dursa sətir
  /// TAMAMILƏ gizlədilir — Google Play buraxılışında bu funksiya yoxdur
  /// (manifestdə icazə silinib), yoxlanılmayan giriş nöqtəsi göstərmək
  /// çaşdırıcı olardı.
  final VoidCallback? onOpenRoutine;
  final VoidCallback onTestNotification;

  /// Cari hesabın e-poçtu.
  final String email;

  /// "Çıxış" — sessiyanı bitirir (hesab silinmir, yenidən giriş mümkündür).
  final VoidCallback onLogout;

  /// "Hesabı sil" təsdiqləndikdən sonra çağırılır — GERİ QAYTARILMAZ (Google
  /// Play tələbi: hesab sistemi olan tətbiqlər hesab silməni təmin etməlidir).
  final Future<void> Function() onDeleteAccount;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı silmək istəyirsən?'),
        content: const Text(
          'Bu əməliyyat geri qaytarıla bilməz — hesabın və bütün rutin/məkan '
          'datan həmişəlik silinəcək.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ləğv et'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDeleteAccount();
  }

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
          if (onOpenRoutine != null)
            _Item(
              icon: Icons.explore_outlined,
              title: 'Rutin öyrənmə',
              subtitle: 'Arxa fon məkan icazəsi',
              onTap: onOpenRoutine,
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, 16, 8),
            child: Text('Hesab',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
          _Item(
            icon: Icons.person_outline,
            title: email,
            subtitle: 'Kabinetin',
            onTap: null,
          ),
          _Item(
            icon: Icons.logout,
            title: 'Çıxış',
            subtitle: 'Yenidən giriş edə bilərsən',
            onTap: onLogout,
          ),
          _Item(
            icon: Icons.delete_outline,
            title: 'Hesabı sil',
            subtitle: 'Bütün datanı həmişəlik sil',
            titleColor: theme.colorScheme.error,
            onTap: () => _confirmDelete(context),
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
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;

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
        child: Icon(icon,
            color: titleColor ?? theme.colorScheme.onSecondaryContainer,
            size: 20),
      ),
      title: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600, color: titleColor)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right, color: theme.colorScheme.outlineVariant),
      onTap: onTap,
    );
  }
}
