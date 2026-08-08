import 'package:flutter/material.dart';

import '../data/pack_repository.dart';
import '../data/review_repository.dart';
import '../services/speaker.dart';
import 'card_session_screen.dart';

/// Bu gün toxunulan sözlərdən ~2 dəqiqəlik axşam təkrarı (spec §3.2 ReviewEngine).
/// Sözləri ReviewRepository.reviewedOn(bugün)-dən götürüb eyni kart sessiyasını
/// (CardSessionScreen) işlədir ki, "Bilirəm/Sonra" cavabı yenidən intervalı yeniləsin.
class EveningQuizScreen extends StatelessWidget {
  const EveningQuizScreen({
    super.key,
    required this.packRepository,
    required this.reviewRepository,
    required this.speaker,
  });

  final PackRepository packRepository;
  final ReviewRepository reviewRepository;
  final Speaker speaker;

  List<SessionEntry> _todaysEntries() {
    final keys = reviewRepository.reviewedOn(DateTime.now());
    final entries = <SessionEntry>[];
    for (final key in keys) {
      final separator = key.indexOf(':');
      if (separator < 0) continue;
      final packId = key.substring(0, separator);
      final wordText = key.substring(separator + 1);
      final pack = packRepository.byId(packId);
      final word = pack?.words.where((w) => w.word == wordText).firstOrNull ??
          reviewRepository.wordForKey(key);
      if (word == null) continue;
      entries.add(SessionEntry(wordKey: key, word: word));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _todaysEntries();
    if (entries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Axşam təkrarı')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bu gün hələ heç bir söz öyrənməmisiniz.\nBir paket açıb başlayın!',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return CardSessionScreen(
      title: 'Axşam təkrarı (${entries.length} söz)',
      entries: entries,
      speaker: speaker,
      reviewRepository: reviewRepository,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
