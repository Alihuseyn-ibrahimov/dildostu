import 'package:flutter/material.dart';

import '../data/review_repository.dart';

/// Öyrənmə statistikası: toxunulan/mənimsənilmiş söz sayı, gündəlik streak.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.reviewRepository});

  final ReviewRepository reviewRepository;

  @override
  Widget build(BuildContext context) {
    final wordCount = reviewRepository.wordCount;
    final masteredCount = reviewRepository.masteredCount;
    final streak = reviewRepository.currentStreak(today: DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Statistika')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatCard(
              icon: Icons.local_fire_department,
              label: 'Ardıcıl gün',
              value: '$streak',
            ),
            const SizedBox(height: 12),
            _StatCard(
              icon: Icons.translate,
              label: 'Toxunulan söz',
              value: '$wordCount',
            ),
            const SizedBox(height: 12),
            _StatCard(
              icon: Icons.star,
              label: 'Mənimsənilmiş söz',
              value: '$masteredCount',
            ),
          ],
        ),
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
