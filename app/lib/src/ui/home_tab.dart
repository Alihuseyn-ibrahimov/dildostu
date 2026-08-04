import 'package:flutter/material.dart';

import '../data/pack_repository.dart';
import '../models/user_profile.dart';
import 'accent_colors.dart';
import 'pack_icons.dart';
import 'theme.dart';

/// Bir paket üçün canlı AI kartı açan callback (main.dart-da bağlanır).
typedef OpenLive = void Function(String packId, String title, UserProfile profile);

/// Cari yeri müəyyən edən callback — tapılsa paket + başlıq + yerin adı.
typedef ResolveLivePlace
    = Future<({String packId, String title, String placeName})?> Function();

/// Ana səhifə tabı — salamlama, çətinlik seçicisi, canlı məkan kartı və
/// ikonlu paket şəbəkəsi (spec §4).
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.repository,
    required this.profile,
    required this.openLive,
    required this.onManualPlace,
    this.onLevelChanged,
    this.resolveLivePlace,
    this.onOpenEssentialWords,
    this.onOpenAudiobooks,
    this.now,
  });

  final PackRepository repository;
  final UserProfile profile;
  final OpenLive openLive;
  final VoidCallback onManualPlace;

  /// "Əsas lüğət" (504 ümumi söz bankı) ekranını açır. Kontekstdən (məkan)
  /// asılı olmadığı üçün paket şəbəkəsindən ayrı, öz kartı var. Null olsa
  /// kart göstərilmir.
  final VoidCallback? onOpenEssentialWords;

  /// Səsli kitablar bölməsi. Null olsa kart göstərilmir.
  final VoidCallback? onOpenAudiobooks;

  /// Çətinlik səviyyəsi dəyişdikdə (profilə saxlanır). Null-dursa seçici
  /// göstərilmir.
  final ValueChanged<ProficiencyLevel>? onLevelChanged;

  /// Cari yeri canlı müəyyən edir (GPS→server). Null olsa kart manual rejimə
  /// keçir (köhnə davranış).
  final ResolveLivePlace? resolveLivePlace;

  /// Salamlama mətnini vaxta görə seçmək üçün (testdə sabitlənir).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final packs = repository.packs;
    // Yeniləmə zolağı QƏSDƏN burada YOXDUR — server v25-də yeni versiya
    // aşkarlananda "Yenilə" zolağının Column-a dinamik əlavə olunması
    // Samsung S926B-də ListView-in aşağısını əbədi NEEDS-LAYOUT/NEEDS-PAINT
    // vəziyyətində qoyub tam boş göstərirdi (heç bir Dart/native xəta
    // olmadan — VM Service widget dump-ı ilə təsdiqləndi). Yeniləmə indi
    // yalnız Ayarlar ekranında göstərilir (bax `SettingsScreen`), o, Ana
    // səhifədən tam ayrı bir marşrutdur və bu problemi kökündən aradan
    // qaldırır.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen, AppSpacing.screen, AppSpacing.screen, 12),
                children: [
                  Text(greetingFor(now ?? DateTime.now()),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 2),
                  Text('Bu gün nə öyrənək?',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (onLevelChanged != null) ...[
                    const SizedBox(height: AppSpacing.section),
                    _LevelSelector(
                      value: profile.level,
                      onChanged: onLevelChanged!,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.section),
                  _LiveContextCard(
                    resolve: resolveLivePlace,
                    levelLabel: profile.level.labelAz,
                    onManualTap: onManualPlace,
                    onOpenPack: (packId, title) =>
                        openLive(packId, title, profile),
                  ),
                  if (onOpenEssentialWords != null) ...[
                    const SizedBox(height: AppSpacing.section),
                    _FeatureCard(
                      icon: Icons.menu_book_outlined,
                      title: 'Əsas lüğət',
                      subtitle: '504 ən çox işlənən söz — səviyyənə uyğun',
                      accent: accentFor('essential'),
                      onTap: onOpenEssentialWords!,
                    ),
                  ],
                  if (onOpenAudiobooks != null) ...[
                    const SizedBox(height: AppSpacing.card),
                    _FeatureCard(
                      icon: Icons.headphones,
                      title: 'Səsli kitablar',
                      subtitle: 'Dinlə və eyni vaxtda mətni oxu',
                      accent: accentFor('audiobooks'),
                      onTap: onOpenAudiobooks!,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.section),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text('Söz paketləri',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text('${packs.length} mövzu',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.card),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.card,
                      crossAxisSpacing: AppSpacing.card,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: packs.length,
                    itemBuilder: (context, i) {
                      final pack = packs[i];
                      return _PackCard(
                        title: pack.titleAz,
                        subtitle:
                            '${pack.words.length} söz · ${profile.level.labelAz.toLowerCase()}',
                        icon: packIcon(pack.packId),
                        accent: accentFor(pack.packId),
                        onTap: () =>
                            openLive(pack.packId, pack.titleAz, profile),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Günün vaxtına uyğun salamlama.
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 6) return 'Gecən xeyrə';
  if (hour < 12) return 'Sabahın xeyir';
  if (hour < 18) return 'Günortan xeyir';
  return 'Axşamın xeyir';
}

/// Çətinlik səviyyəsi seçicisi — seçim bütün paketlərə tətbiq olunur (spec §1).
class _LevelSelector extends StatelessWidget {
  const _LevelSelector({required this.value, required this.onChanged});

  final ProficiencyLevel value;
  final ValueChanged<ProficiencyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Çətinlik səviyyəsi',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ProficiencyLevel>(
            showSelectedIcon: false,
            segments: [
              for (final level in ProficiencyLevel.values)
                ButtonSegment(value: level, label: Text(level.labelAz)),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
        const SizedBox(height: 6),
        Text(value.hintAz,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}

/// "İndi haradayam?" — açılışda cari yeri GPS+server ilə tapıb göstərir.
/// Yer tapılsa toxunuş həmin paketi açır; tapılmasa manual rejimə keçir.
class _LiveContextCard extends StatefulWidget {
  const _LiveContextCard({
    required this.resolve,
    required this.levelLabel,
    required this.onManualTap,
    required this.onOpenPack,
  });

  final ResolveLivePlace? resolve;
  final String levelLabel;
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
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: onColor),
      );
      onTap = () {};
    } else if (_place != null) {
      final place = _place!;
      titleText =
          place.placeName.isNotEmpty ? place.placeName : place.title;
      subtitleText =
          '${place.title} · ${widget.levelLabel.toLowerCase()} səviyyə';
      leading = Icon(Icons.my_location, color: onColor);
      onTap = () => widget.onOpenPack(place.packId, place.title);
    } else {
      titleText = 'İndi haradayam?';
      subtitleText = 'Olduğun yerə uyğun sözlər';
      leading = Icon(Icons.place_outlined, color: onColor);
      onTap = widget.onManualTap;
    }

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: onColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: onColor)),
                  ],
                ),
              ),
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

/// Kontekstdən (məkandan) asılı olmayan bölmə kartı — "Əsas lüğət",
/// "Səsli kitablar" kimi. Paket şəbəkəsindən ayrı, tam enli göstərilir.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Xüsusiyyətin sabit aksent rəngi (bax `accent_colors.dart`). Null olsa
  /// mövcud neytral `secondaryContainer` işlədilir.
  final AccentColor? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = accent?.tint ?? theme.colorScheme.secondaryContainer;
    final onColor = accent?.accent ?? theme.colorScheme.onSecondaryContainer;
    return Card(
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: onColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: onColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: onColor)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: onColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Şəbəkə düzümündə paket kartı — rəngli ikon plitəsi + ad + alt sətir.
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  /// Paketin sabit aksent rəngi (bax `accent_colors.dart`). Null olsa
  /// mövcud neytral `secondaryContainer` işlədilir.
  final AccentColor? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = accent?.tint ?? theme.colorScheme.secondaryContainer;
    final iconColor = accent?.accent ?? theme.colorScheme.onSecondaryContainer;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
