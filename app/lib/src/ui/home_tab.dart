import 'package:flutter/material.dart';

import '../data/pack_repository.dart';
import '../engine/pack_titles.dart';
import '../l10n/app_locale_scope.dart';
import '../models/live_message.dart';
import '../models/user_profile.dart';
import 'accent_colors.dart';
import 'brand.dart';
import 'pack_icons.dart';
import 'playful_ui.dart';
import 'theme.dart';

/// Bir paket üçün canlı AI kartı açan callback (main.dart-da bağlanır).
typedef OpenLive = void Function(String packId, String title, UserProfile profile);

/// Canlı məkan kartının vəziyyəti — uğur VƏ uğursuzluq bir tipdə.
class LivePlaceState {
  const LivePlaceState._({
    this.packId,
    this.title = '',
    this.placeName = '',
    this.distanceM,
    this.approximate = false,
    this.error,
  });

  factory LivePlaceState.resolved({
    String? packId,
    String title = '',
    String placeName = '',
    int? distanceM,
    bool approximate = false,
  }) =>
      LivePlaceState._(
        packId: packId,
        title: title,
        placeName: placeName,
        distanceM: distanceM,
        approximate: approximate,
      );

  factory LivePlaceState.failed(String message) =>
      LivePlaceState._(error: message);

  final String? packId;
  final String title;
  final String placeName;
  final int? distanceM;
  final bool approximate;
  final String? error;

  bool get isSuccess => error == null;
  bool get canOpenPack => packId != null && packId!.isNotEmpty;
}

typedef ResolveLivePlace = Future<LivePlaceState> Function({bool forceRefresh});

/// Gündəlik AI missiyasını yükləyir (`/day-plan`, gündəlik keş).
typedef LoadDayPlan = Future<({List<LiveMessage> messages, bool isLive})> Function({
  bool forceRefresh,
});

/// Missiya sözünə toxunanda detallı ekranı açır.
typedef OpenDayPlanWord = void Function(List<LiveMessage> words, int index);

/// Ana səhifə — Duolingo tipli oyunvari, LachinGo səyahət unikallığı ilə.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.repository,
    required this.profile,
    required this.openLive,
    required this.onManualPlace,
    this.onLevelChanged,
    this.currentLanguage,
    this.onLanguageChanged,
    this.resolveLivePlace,
    this.onOpenEssentialWords,
    this.onOpenAudiobooks,
    this.onOpenMusic,
    this.loadDayPlan,
    this.onOpenDayPlanWord,
    this.now,
  });

  final PackRepository repository;
  final UserProfile profile;
  final OpenLive openLive;
  final VoidCallback onManualPlace;
  final VoidCallback? onOpenEssentialWords;
  final VoidCallback? onOpenAudiobooks;
  final VoidCallback? onOpenMusic;
  final ValueChanged<ProficiencyLevel>? onLevelChanged;
  final TargetLanguage? currentLanguage;
  final ValueChanged<TargetLanguage>? onLanguageChanged;
  final ResolveLivePlace? resolveLivePlace;
  final LoadDayPlan? loadDayPlan;
  final OpenDayPlanWord? onOpenDayPlanWord;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final packs = repository.packs;
    final s = context.s;
    final levelName = s.proficiencyLabel(profile.level).toLowerCase();
    final nowDt = now ?? DateTime.now();
    return PlayfulScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.screen,
              AppSpacing.screen,
              12,
            ),
            children: [
              PlayfulHomeHero(
                greeting: s.greetingForHour(nowDt.hour),
                headline: s.homeHeroHeadline,
                trailing: onLanguageChanged != null
                    ? _LanguagePicker(
                        value: currentLanguage ?? TargetLanguage.english,
                        onChanged: onLanguageChanged!,
                      )
                    : null,
              ),
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
                levelLabel: s.proficiencyLabel(profile.level),
                onManualTap: onManualPlace,
                onOpenPack: (packId, title) =>
                    openLive(packId, title, profile),
              ),
              if (loadDayPlan != null && onOpenDayPlanWord != null) ...[
                const SizedBox(height: AppSpacing.section),
                _DailyMissionCard(
                  loadDayPlan: loadDayPlan!,
                  onOpenWord: onOpenDayPlanWord!,
                ),
              ],
              if (onOpenEssentialWords != null ||
                  onOpenAudiobooks != null ||
                  onOpenMusic != null) ...[
                const SizedBox(height: AppSpacing.section),
                PlayfulSectionHeader(
                  title: s.missionsSection,
                  subtitle: s.missionsSubtitle,
                  emoji: '🎯',
                  accent: BrandColors.gold,
                ),
                const SizedBox(height: AppSpacing.card),
              ],
              if (onOpenEssentialWords != null)
                _FeatureCard(
                  icon: Icons.menu_book_rounded,
                  title: s.essentialWords,
                  subtitle: s.essentialWordsSubtitle(levelName),
                  badge: '504',
                  accent: accentFor('essential'),
                  onTap: onOpenEssentialWords!,
                ),
              if (onOpenAudiobooks != null) ...[
                const SizedBox(height: AppSpacing.card),
                _FeatureCard(
                  icon: Icons.headphones_rounded,
                  title: s.audiobooks,
                  subtitle: s.audiobooksSubtitle,
                  badge: 'DİN',
                  accent: accentFor('audiobooks'),
                  onTap: onOpenAudiobooks!,
                ),
              ],
              if (onOpenMusic != null) ...[
                const SizedBox(height: AppSpacing.card),
                _FeatureCard(
                  icon: Icons.music_note_rounded,
                  title: s.music,
                  subtitle: s.musicSubtitle(s.proficiencyLabel(profile.level)),
                  badge: '♪',
                  accent: accentFor('music'),
                  onTap: onOpenMusic!,
                ),
              ],
              const SizedBox(height: AppSpacing.section),
              PlayfulSectionHeader(
                title: s.wordPacks,
                subtitle: s.wordPacksSubtitle(packs.length),
                icon: Icons.flight_takeoff_rounded,
                accent: BrandColors.navy,
              ),
              const SizedBox(height: AppSpacing.card),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.card,
                  crossAxisSpacing: AppSpacing.card,
                  childAspectRatio: 0.95,
                ),
                itemCount: packs.length,
                itemBuilder: (context, i) {
                  final pack = packs[i];
                  return _PackCard(
                    title: pack.titleAz,
                    subtitle: s.wordsAtLevel(
                      pack.words.length,
                      levelName,
                    ),
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
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.value, required this.onChanged});

  final TargetLanguage value;
  final ValueChanged<TargetLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TargetLanguage>(
      key: const Key('home-language-picker'),
      tooltip: context.s.changeLearningLanguage,
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final lang in TargetLanguage.values)
          PopupMenuItem(
            value: lang,
            child: Row(
              children: [
                Text(lang.flagEmoji, style: const TextStyle(fontSize: 18, height: 1)),
                const SizedBox(width: 8),
                Expanded(child: Text(lang.nativeLabel)),
                if (lang == value)
                  const Icon(Icons.check_rounded, size: 18, color: BrandColors.gold),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value.flagEmoji, style: const TextStyle(fontSize: 16, height: 1)),
            const SizedBox(width: 5),
            Text(
              value.nativeLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({required this.value, required this.onChanged});

  final ProficiencyLevel value;
  final ValueChanged<ProficiencyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlayfulSectionHeader(
          title: s.difficultyLevel,
          emoji: '🧭',
          accent: BrandColors.navy,
        ),
        const SizedBox(height: 10),
        PlayfulPillSelector<ProficiencyLevel>(
          values: ProficiencyLevel.values,
          selected: value,
          onChanged: onChanged,
          labelFor: s.proficiencyLabel,
          accent: BrandColors.navy,
        ),
        const SizedBox(height: 8),
        Text(
          value.hintAz,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

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
  LivePlaceState? _state;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve({bool forceRefresh = false}) async {
    if (widget.resolve == null) return;
    setState(() => _loading = true);
    final result = await widget.resolve!(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _state = result;
    });
  }

  String _subtitleFor(LivePlaceState place) {
    final s = context.s;
    final parts = <String>[];
    if (place.title.isNotEmpty) parts.add(place.title);
    if (place.distanceM != null) parts.add('${place.distanceM} m');
    if (place.approximate) parts.add(s.approximateLabel);
    if (!place.canOpenPack) {
      parts.add(s.noWordPack);
    } else if (parts.length < 3) {
      parts.add(s.levelSuffix(widget.levelLabel.toLowerCase()));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.s;

    final String titleText;
    final String subtitleText;
    final Widget leading;
    final VoidCallback onTap;
    var subtitleMaxLines = 1;
    var isAdventure = false;

    final place = _state;
    if (_loading) {
      titleText = s.locatingTitle;
      subtitleText = s.locatingSubtitle;
      leading = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
      );
      onTap = () {};
      isAdventure = true;
    } else if (place != null && place.isSuccess) {
      titleText = place.placeName.isNotEmpty ? place.placeName : place.title;
      subtitleText = _subtitleFor(place);
      leading = Icon(
        place.approximate ? Icons.location_searching : Icons.my_location,
        color: BrandColors.gold,
        size: 26,
      );
      onTap = place.canOpenPack
          ? () => widget.onOpenPack(place.packId!, place.title)
          : widget.onManualTap;
      isAdventure = true;
    } else if (place != null) {
      titleText = s.locationFailed;
      subtitleText = place.error!;
      subtitleMaxLines = 3;
      leading = const Icon(Icons.location_disabled,
          color: Colors.white70, size: 26);
      onTap = widget.onManualTap;
      isAdventure = true;
    } else {
      titleText = s.whereAmI;
      subtitleText = s.whereAmISubtitle;
      leading = const Icon(Icons.explore_rounded,
          color: BrandColors.gold, size: 26);
      onTap = widget.onManualTap;
      isAdventure = true;
    }

    final cardColor =
        isAdventure ? BrandColors.navy : theme.colorScheme.primaryContainer;
    final shadow = PlayfulCard.shadowFor(cardColor);
    final onColor = Colors.white;

    return PlayfulCard(
      color: cardColor,
      shadowColor: shadow,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: leading,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PlayfulBadge(label: s.liveBadge),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: onColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleText,
                  maxLines: subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (widget.resolve != null && !_loading)
            IconButton(
              onPressed: () => _resolve(forceRefresh: true),
              icon: Icon(Icons.refresh, color: onColor),
              tooltip: s.refreshLocationTooltip,
            )
          else
            Icon(Icons.chevron_right_rounded, color: onColor),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.badge,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String badge;
  final AccentColor? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = accent ?? accentFor('essential');
    return PlayfulCard(
      color: a.tint,
      shadowColor: PlayfulCard.shadowFor(a.accent),
      onTap: onTap,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: a.accent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: PlayfulCard.shadowFor(a.accent),
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Icon(icon, color: a.onAccent, size: 24),
              ),
              Positioned(
                top: -4,
                right: -6,
                child: PlayfulBadge(label: badge, color: BrandColors.gold),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: a.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: a.accent.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: a.accent),
        ],
      ),
    );
  }
}

/// Pasport möhürü tipli paket kartı — tam rəngli fon + 3D kölgə.
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
  final AccentColor? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = accent ?? accentFor('essential');
    return PlayfulCard(
      color: a.tint,
      shadowColor: PlayfulCard.shadowFor(a.accent),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: a.tint,
              borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
              border: Border.all(color: a.accent.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: a.accent, size: 22),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ana səhifədə gündəlik AI missiya kartı (`/day-plan`).
class _DailyMissionCard extends StatefulWidget {
  const _DailyMissionCard({
    required this.loadDayPlan,
    required this.onOpenWord,
  });

  final LoadDayPlan loadDayPlan;
  final OpenDayPlanWord onOpenWord;

  @override
  State<_DailyMissionCard> createState() => _DailyMissionCardState();
}

class _DailyMissionCardState extends State<_DailyMissionCard> {
  bool _loading = true;
  String? _error;
  List<LiveMessage> _messages = const [];
  bool _isLive = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.loadDayPlan(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _messages = result.messages;
        _isLive = result.isLive;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);

    return PlayfulCard(
      color: BrandColors.gold.withValues(alpha: 0.12),
      shadowColor: PlayfulCard.shadowFor(BrandColors.gold),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🎯  ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.dailyMissionTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!_loading && _error == null && _messages.isNotEmpty)
                      Text(
                        _isLive
                            ? s.dailyMissionSubtitle(_messages.length)
                            : s.dailyMissionOffline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              if (!_loading)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: s.dailyMissionRefresh,
                  onPressed: () => _load(forceRefresh: true),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 10),
                Text(s.dailyMissionLoading),
              ],
            )
          else if (_error != null) ...[
            Text(
              s.dailyMissionFailed(_error!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _load(forceRefresh: true),
                child: Text(s.dailyMissionRetry),
              ),
            ),
          ] else if (_messages.isEmpty)
            Text(
              s.dailyMissionFailed('boş siyahı'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          else
            ...List.generate(_messages.length, (i) {
              final msg = _messages[i];
              final packTitle = packTitleAz(msg.packId);
              final accent = accentFor(msg.packId);
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: Material(
                  color: accent.tint,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => widget.onOpenWord(_messages, i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(packIcon(msg.packId),
                              color: accent.accent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.word,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${msg.translationAz} · $packTitle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: theme.colorScheme.outline),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
