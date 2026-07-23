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

    return Scaffold(
      appBar: AppBar(title: const Text('İrəliləyiş')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(
              icon: Icons.local_fire_department,
              label: 'Ardıcıl gün',
              value: '$streak'),
          const SizedBox(height: 12),
          _StatCard(
              icon: Icons.translate,
              label: 'Toxunulan söz',
              value: '$wordCount'),
          const SizedBox(height: 12),
          _StatCard(
              icon: Icons.star,
              label: 'Mənimsənilmiş söz',
              value: '$masteredCount'),
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 32),
        title: Text(label),
        trailing: Text(value, style: theme.textTheme.headlineSmall),
      ),
    );
  }
}
