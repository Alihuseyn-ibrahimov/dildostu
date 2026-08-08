import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';
import 'brand.dart';
import 'playful_ui.dart';
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
    final s = context.s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteAccountTitle),
        content: Text(s.deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDeleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;
    return PlayfulScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(s.profileTitle)),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
          _Item(
            icon: Icons.settings_outlined,
            title: s.settingsMenu,
            subtitle: s.settingsMenuSubtitle,
            onTap: onOpenSettings,
          ),
          _Item(
            icon: Icons.insights_outlined,
            title: s.aiLearnedTitle,
            subtitle: s.aiLearnedSubtitle,
            onTap: onOpenLearned,
          ),
          if (onOpenRoutine != null)
            _Item(
              icon: Icons.explore_outlined,
              title: s.routineLearning,
              subtitle: s.routineSubtitle,
              onTap: onOpenRoutine,
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, 16, 8),
            child: Text(s.accountSection,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
          _Item(
            icon: Icons.person_outline,
            title: email,
            subtitle: s.accountCabinet,
            onTap: null,
          ),
          _Item(
            icon: Icons.logout,
            title: s.logout,
            subtitle: s.logoutSubtitle,
            onTap: onLogout,
          ),
          _Item(
            icon: Icons.delete_outline,
            title: s.deleteAccount,
            subtitle: s.deleteAccountSubtitle,
            titleColor: theme.colorScheme.error,
            onTap: () => _confirmDelete(context),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, 16, 8),
            child: Text(s.developerSection,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
          _Item(
            icon: Icons.notifications_active_outlined,
            title: s.testNotifTitle,
            subtitle: s.testNotifSubtitle,
            onTap: onTestNotification,
          ),
        ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: 4,
      ),
      child: PlayfulCard(
        color: Colors.white,
        shadowColor: theme.colorScheme.outlineVariant,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderRadius: AppSpacing.radiusControl,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: BrandColors.navy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: titleColor ?? BrandColors.navy,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}
