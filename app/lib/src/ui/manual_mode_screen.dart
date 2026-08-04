import 'package:flutter/material.dart';

import '../data/manual_context_repository.dart';
import '../data/pack_repository.dart';
import '../data/review_repository.dart';
import '../services/speaker.dart';
import 'accent_colors.dart';
import 'card_session_screen.dart';

/// "İndi haradayam?" — istifadəçi kateqoriyanı özü seçir (spec §3.2 manual
/// rejim, ən yüksək prioritet). Seçim ManualContextRepository-də 2 saat
/// saxlanır ki, növbəti bildirişlər də bu kontekstə uyğun olsun.
class ManualModeScreen extends StatelessWidget {
  const ManualModeScreen({
    super.key,
    required this.packRepository,
    required this.reviewRepository,
    required this.manualContextRepository,
    required this.speaker,
  });

  final PackRepository packRepository;
  final ReviewRepository reviewRepository;
  final ManualContextRepository manualContextRepository;
  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    final packs = packRepository.packs;
    return Scaffold(
      appBar: AppBar(title: const Text('İndi haradayam?')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: packs.length,
        itemBuilder: (context, i) {
          final pack = packs[i];
          final accent = accentFor(pack.packId);
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: accent.tint,
                foregroundColor: accent.accent,
                child: const Icon(Icons.place_outlined, size: 18),
              ),
              title: Text(pack.titleAz),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await manualContextRepository.set(pack.packId, now: DateTime.now());
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => CardSessionScreen(
                      title: pack.titleAz,
                      entries: [
                        for (final word in pack.words)
                          SessionEntry(
                            wordKey: '${pack.packId}:${word.word}',
                            word: word,
                          ),
                      ],
                      speaker: speaker,
                      reviewRepository: reviewRepository,
                      accent: accent,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
