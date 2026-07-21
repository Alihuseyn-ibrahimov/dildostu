import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/speaker.dart';

/// İstifadəçinin söz kartına verdiyi cavab (Phase 3-də ReviewEngine bunu işlədir).
enum ReviewOutcome { known, later }

/// Bir sözü göstərən kart: böyük yazı + IPA + tərcümə + nümunə cümlə,
/// səsləndirmə düyməsi və "Bilirəm / Sonra" cavab düymələri.
class WordCardView extends StatelessWidget {
  const WordCardView({
    super.key,
    required this.word,
    required this.speaker,
    required this.onReview,
  });

  final Word word;
  final Speaker speaker;
  final ValueChanged<ReviewOutcome> onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            word.word,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            word.ipa,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Text(
            word.translationAz,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(word.example, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    word.exampleAz,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () => speaker.speak(word.word),
            icon: const Icon(Icons.volume_up),
            label: const Text('Səsləndir'),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onReview(ReviewOutcome.later),
                  child: const Text('↻ Sonra'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => onReview(ReviewOutcome.known),
                  child: const Text('✓ Bilirəm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
