import 'package:flutter/material.dart';

import '../data/pack_repository.dart';
import '../models/app_version_info.dart';
import '../models/user_profile.dart';
import 'pack_icons.dart';
import 'update_banner.dart';

/// Bir paket üçün canlı AI kartı açan callback (main.dart-da bağlanır).
typedef OpenLive = void Function(String packId, String title, UserProfile profile);

/// Ana səhifə tabı — salamlama başlığı, "İndi haradayam?" kontekst kartı və
/// ikonlu söz paketləri. Update banner varsa yuxarıda göstərilir.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.repository,
    required this.profile,
    required this.openLive,
    required this.onManualPlace,
    this.availableUpdate,
    this.onInstallUpdate,
  });

  final PackRepository repository;
  final UserProfile profile;
  final OpenLive openLive;
  final VoidCallback onManualPlace;
  final AppVersionInfo? availableUpdate;
  final VoidCallback? onInstallUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final packs = repository.packs;
    return Scaffold(
      appBar: AppBar(title: const Text('DilDostu')),
      body: Column(
        children: [
          if (availableUpdate != null)
            UpdateBanner(info: availableUpdate!, onInstall: onInstallUpdate!),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
                Text('Salam 👋',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Bu gün hansı sözləri öyrənək?',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 16),
                _ContextCard(onTap: onManualPlace),
                const SizedBox(height: 20),
                Text('Söz paketləri',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final pack in packs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PackCard(
                      title: pack.titleAz,
                      subtitle: '${pack.words.length} söz',
                      icon: packIcon(pack.packId),
                      onTap: () => openLive(pack.packId, pack.titleAz, profile),
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

/// "İndi haradayam?" — məkan konteksti üçün cəlbedici kart.
class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.place, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('İndi haradayam?',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600)),
                    Text('Olduğun yerə uyğun sözlər',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// İkonlu böyük söz paketi kartı.
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: theme.colorScheme.onSecondaryContainer, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
