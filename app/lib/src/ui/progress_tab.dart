import 'package:flutter/material.dart';

import '../data/pack_repository.dart';
import '../data/review_repository.dart';
import '../services/speaker.dart';
import 'evening_quiz_screen.dart';

/// İrəliləyiş tabı — öyrənmə statistikası (streak, söz sayı) + axşam təkrarına
/// keçid. StatsScreen + EveningQuiz birləşmiş görünüşü.
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
    final wordCount = reviewRepository.wordCount;
    final masteredCount = reviewRepository.masteredCount;
    final streak = reviewRepository.currentStreak(today: DateTime.now());

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('İrəliləyiş')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Streak hero kartı
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: theme.colorScheme.onPrimaryContainer, size: 40),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$streak gün',
                          style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold)),
                      Text('ardıcıl öyrənmə',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _MetricCard(
                      icon: Icons.translate,
                      label: 'Toxunulan söz',
                      value: '$wordCount')),
              const SizedBox(width: 12),
              Expanded(
                  child: _MetricCard(
                      icon: Icons.star,
                      label: 'Mənimsənilmiş',
                      value: '$masteredCount')),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EveningQuizScreen(
                  packRepository: packRepository,
                  reviewRepository: reviewRepository,
                  speaker: speaker,
                ),
              ),
            ),
            icon: const Icon(Icons.nightlight_round),
            label: const Text('Axşam təkrarı'),
          ),
        ],
      ),
    );
  }
}

/// Kiçik metrik kartı (ikon + böyük rəqəm + etiket).
class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(height: 10),
            Text(value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
