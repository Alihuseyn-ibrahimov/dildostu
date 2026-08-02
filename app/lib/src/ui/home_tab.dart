import 'package:flutter/material.dart';

import '../data/pack_repository.dart';
import '../models/app_version_info.dart';
import '../models/user_profile.dart';
import 'pack_icons.dart';
import 'update_banner.dart';

/// Bir paket üçün canlı AI kartı açan callback (main.dart-da bağlanır).
typedef OpenLive = void Function(String packId, String title, UserProfile profile);

/// Cari yeri müəyyən edən callback — tapılsa paket + başlıq + yerin adı.
typedef ResolveLivePlace
    = Future<({String packId, String title, String placeName})?> Function();

/// Ana səhifə tabı — salamlama, canlı "İndi haradayam?" məkan kartı və ikonlu
/// söz paketləri. Update banner varsa yuxarıda göstərilir.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.repository,
    required this.profile,
    required this.openLive,
    required this.onManualPlace,
    this.resolveLivePlace,
    this.availableUpdate,
    this.onInstallUpdate,
  });

  final PackRepository repository;
  final UserProfile profile;
  final OpenLive openLive;
  final VoidCallback onManualPlace;

  /// Cari yeri canlı müəyyən edir (GPS→server). Null olsa kart manual rejimə
  /// keçir (köhnə davranış).
  final ResolveLivePlace? resolveLivePlace;
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
                _LiveContextCard(
                  resolve: resolveLivePlace,
                  onManualTap: onManualPlace,
                  onOpenPack: (packId, title) =>
                      openLive(packId, title, profile),
                ),
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

/// "İndi haradayam?" — açılışda cari yeri GPS+server ilə tapıb göstərir.
/// Yer tapılsa toxunuş həmin paketi açır; tapılmasa manual rejimə keçir.
class _LiveContextCard extends StatefulWidget {
  const _LiveContextCard({
    required this.resolve,
    required this.onManualTap,
    required this.onOpenPack,
  });

  final ResolveLivePlace? resolve;
  final VoidCallback onManualTap;
  final void Function(String packId, String title) onOpenPack;

  @override
  State<_LiveContextCard> createState() => _LiveContextCardState();
}

class _LiveContextCardState extends State<_LiveContextCard> {
  bool _loading = false;
  ({String packId, String title, String placeName})? _place;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    if (widget.resolve == null) return;
    setState(() => _loading = true);
    final result = await widget.resolve!();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _place = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onPrimaryContainer;

    final String titleText;
    final String subtitleText;
    final Widget leading;
    final VoidCallback onTap;

    if (_loading) {
      titleText = 'Yerini müəyyən edirəm…';
      subtitleText = 'Bir saniyə';
      leading = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: onColor),
      );
      onTap = () {};
    } else if (_place != null) {
      final place = _place!;
      titleText = place.placeName.isNotEmpty
          ? '📍 ${place.placeName}'
          : place.title;
      subtitleText = '${place.title} sözlərinə bax';
      leading = Icon(Icons.my_location, color: onColor);
      onTap = () => widget.onOpenPack(place.packId, place.title);
    } else {
      titleText = 'İndi haradayam?';
      subtitleText = 'Olduğun yerə uyğun sözlər';
      leading = Icon(Icons.place, color: onColor);
      onTap = widget.onManualTap;
    }

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleText,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: onColor, fontWeight: FontWeight.w600)),
                    Text(subtitleText,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: onColor)),
                  ],
                ),
              ),
              // Yenilə düyməsi (yer dəyişəndə əl ilə təzələmək üçün).
              if (widget.resolve != null && !_loading)
                IconButton(
                  onPressed: _resolve,
                  icon: Icon(Icons.refresh, color: onColor),
                  tooltip: 'Yeri yenilə',
                )
              else
                Icon(Icons.chevron_right, color: onColor),
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
