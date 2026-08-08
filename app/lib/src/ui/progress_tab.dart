import 'package:flutter/material.dart';

import '../data/pack_repository.dart';
import '../l10n/app_locale_scope.dart';
import '../data/review_repository.dart';
import '../services/speaker.dart';
import 'accent_colors.dart';
import 'brand.dart';
import 'evening_quiz_screen.dart';
import 'playful_ui.dart';
import 'theme.dart';

/// İrəliləyiş tabı — canlı statistika, həftəlik aktivlik, paket xəritəsi,
/// son öyrənilən sözlər və axşam təkrarı.
class ProgressTab extends StatelessWidget {
  const ProgressTab({
    super.key,
    required this.reviewRepository,
    required this.packRepository,
    required this.speaker,
  });

  final ReviewRepository reviewRepository;
  final PackRepository packRepository;
  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: reviewRepository,
      builder: (context, _) {
        final now = DateTime.now();
        final streak = reviewRepository.currentStreak(today: now);
        final today = reviewRepository.todayCount(today: now);
        final touched = reviewRepository.wordCount;
        final learning = reviewRepository.learningCount;
        final mastered = reviewRepository.masteredCount;
        final weekly = reviewRepository.wordsPerDay(today: now);
        final recent = reviewRepository.recentWords(limit: 6);
        final packs = reviewRepository.packBreakdown();

        return PlayfulScreenBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: Text(context.s.progressTitle)),
            body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              8,
              AppSpacing.screen,
              24,
            ),
            children: [
              _StreakHero(
                streak: streak,
                todayCount: today,
                mastered: mastered,
              ),
              const SizedBox(height: AppSpacing.section),
              _StatRow(
                touched: touched,
                learning: learning,
                mastered: mastered,
              ),
              const SizedBox(height: AppSpacing.section),
              _WeeklyActivityChart(values: weekly, today: now),
              if (packs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                Text('Səyahət xəritəsi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const SizedBox(height: 10),
                ...packs.map((p) => _PackProgressTile(
                      stats: p,
                      title: _packTitle(p.packId),
                      accent: accentFor(p.packId),
                      totalWords: packRepository.byId(p.packId)?.words.length,
                    )),
              ],
              if (recent.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                Text('Son öyrəndiklərin',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const SizedBox(height: 10),
                ...recent.map((w) => _RecentWordTile(
                      item: w,
                      packTitle: _packTitle(w.packId),
                      accent: accentFor(w.packId),
                    )),
              ],
              const SizedBox(height: AppSpacing.section),
              _EveningReviewCard(
                todayCount: today,
                onStart: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EveningQuizScreen(
                      packRepository: packRepository,
                      reviewRepository: reviewRepository,
                      speaker: speaker,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  String _packTitle(String packId) {
    if (packId == 'essential') return 'Əsas lüğət';
    return packRepository.byId(packId)?.titleAz ?? packId;
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({
    required this.streak,
    required this.todayCount,
    required this.mastered,
  });

  final int streak;
  final int todayCount;
  final int mastered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PlayfulCard(
      color: BrandColors.navy,
      shadowColor: PlayfulCard.shadowFor(BrandColors.navy),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BrandColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: BrandColors.gold, size: 32),
              ),
              const SizedBox(width: 12),
              Text(
                '$streak',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'gün uçuş streak',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Quş heç enmir 🔥',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BrandColors.gold.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroChip(
                icon: Icons.today_rounded,
                label: 'Bu gün',
                value: '$todayCount söz',
                onPrimary: Colors.white,
              ),
              const SizedBox(width: 10),
              _HeroChip(
                icon: Icons.workspace_premium_rounded,
                label: 'Mənimsənildi',
                value: '$mastered',
                onPrimary: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPrimary,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: onPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: onPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: onPrimary.withValues(alpha: 0.85),
                        fontSize: 11,
                      )),
                  Text(value,
                      style: TextStyle(
                        color: onPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.touched,
    required this.learning,
    required this.mastered,
  });

  final int touched;
  final int learning;
  final int mastered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            icon: Icons.explore_outlined,
            label: 'Kəşf etdin',
            value: touched,
            color: const Color(0xFF5C6BC0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(
            icon: Icons.auto_stories_outlined,
            label: 'Öyrənirsən',
            value: learning,
            color: const Color(0xFFFF8F00),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatPill(
            icon: Icons.star_rounded,
            label: 'Mənimsədin',
            value: mastered,
            color: const Color(0xFF43A047),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PlayfulCard(
      color: color.withValues(alpha: 0.12),
      shadowColor: PlayfulCard.shadowFor(color),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      borderRadius: AppSpacing.radiusPlayful,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyActivityChart extends StatelessWidget {
  const _WeeklyActivityChart({required this.values, required this.today});

  final List<int> values;
  final DateTime today;

  static const _labels = ['B.e.', 'Ç.a.', 'Ç.', 'C.a.', 'C.', 'Ş.', 'B.'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVal = values.fold<int>(0, (m, v) => v > m ? v : m);
    final scale = maxVal == 0 ? 1.0 : maxVal.toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Son 7 gün',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(values.length, (i) {
                  final day = today.subtract(Duration(days: values.length - 1 - i));
                  final isToday = _sameDay(day, today);
                  final h = values[i] == 0 ? 4.0 : (values[i] / scale) * 56 + 8;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: h,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary
                                      .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _labels[day.weekday - 1],
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.normal,
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _PackProgressTile extends StatelessWidget {
  const _PackProgressTile({
    required this.stats,
    required this.title,
    required this.accent,
    this.totalWords,
  });

  final PackProgressStats stats;
  final String title;
  final AccentColor accent;
  final int? totalWords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = totalWords != null && totalWords! > 0
        ? stats.mastered / totalWords!
        : (stats.touched == 0 ? 0.0 : stats.mastered / stats.touched);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        '${stats.touched} toxunuldu · ${stats.mastered} mənimsənildi',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                Text('${(progress * 100).round()}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent.accent,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: accent.tint,
                color: accent.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentWordTile extends StatelessWidget {
  const _RecentWordTile({
    required this.item,
    required this.packTitle,
    required this.accent,
  });

  final WordProgressItem item;
  final String packTitle;
  final AccentColor accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = item.isMastered
        ? ('Mənimsənildi', accent.accent, Icons.check_circle)
        : item.isLearning
            ? ('Öyrənilir', const Color(0xFFFF8F00), Icons.autorenew)
            : ('Yeni', theme.colorScheme.outline, Icons.fiber_new);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: accent.tint,
          child: Text(
            item.word.isNotEmpty ? item.word[0].toUpperCase() : '?',
            style: TextStyle(
              color: accent.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(item.word, style: theme.textTheme.titleSmall),
        subtitle: Text(
          item.translationAz ?? packTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(status.$3, size: 16, color: status.$2),
            Text(status.$1,
                style: theme.textTheme.labelSmall?.copyWith(color: status.$2)),
            _MasteryDots(step: item.step),
          ],
        ),
      ),
    );
  }
}

class _MasteryDots extends StatelessWidget {
  const _MasteryDots({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(masteredStepThreshold, (i) {
        final filled = step > i;
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}

class _EveningReviewCard extends StatelessWidget {
  const _EveningReviewCard({
    required this.todayCount,
    required this.onStart,
  });

  final int todayCount;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasWords = todayCount > 0;
    return Card(
      color: hasWords
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.nightlight_round,
                    color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Axşam təkrarı',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasWords
                  ? 'Bu gün öyrəndiyin $todayCount sözü 2 dəqiqəyə təkrarla.'
                  : 'Bu gün hələ söz öyrənməmisən — paket aç və başla!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer
                    .withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: hasWords ? onStart : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(hasWords ? 'Təkrara başla' : 'Gözləyir'),
            ),
          ],
        ),
      ),
    );
  }
}
