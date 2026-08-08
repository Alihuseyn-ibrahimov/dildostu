/// Səsli kitab fəslində sinxron rəngli mətn üçün vaxt xətləri.
///
/// Musiqi bölməsində vaxtlar ASR-dən gəlir; səsli kitabda Piper TTS
/// generasiyasında söz vaxtları yoxdur. Ona görə fəsil müddəti və söz
/// sayına görə cümlələr arasında **təxmini** paylanma edilir — musiqi
/// karaoke UX-i eyni qalır (`lyrics_sync.dart` + `buildSyncedWordSpans`).
library;

import '../models/song.dart';
import 'lyrics_sync.dart';

/// Mətni cümlələrə bölür (paraqraf və `.!?` sonrası).
List<String> splitChapterSentences(String text) {
  final normalized = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  if (normalized.isEmpty) return const [];

  return normalized
      .split(RegExp(r'(?<=[.!?])\s+|\n\n+'))
      .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Fəsil mətni + real MP3 müddəti → sinxron sətirlər.
///
/// Hər cümləyə `start_ms`/`end_ms` verilir; söz vaxtları yoxdur —
/// `activeWordIndex` sətir daxilində xətti interpolasiya edir.
List<SongLine> buildAudiobookLines(String text, Duration duration) {
  final sentences = splitChapterSentences(text);
  if (sentences.isEmpty) return const [];

  final wordCounts = sentences.map(countWords).toList();
  final totalWords = wordCounts.fold(0, (a, b) => a + b);
  if (totalWords == 0) return const [];

  final totalMs = duration.inMilliseconds;
  if (totalMs <= 0) {
    return [
      for (var i = 0; i < sentences.length; i++)
        SongLine(
          lineId: 'l$i',
          text: sentences[i],
          translationAz: '',
          startMs: 0,
          endMs: 0,
        ),
    ];
  }

  var wordsSeen = 0;
  final lines = <SongLine>[];
  for (var i = 0; i < sentences.length; i++) {
    final startMs = (wordsSeen * totalMs / totalWords).round();
    wordsSeen += wordCounts[i];
    final endMs = (wordsSeen * totalMs / totalWords).round();
    lines.add(
      SongLine(
        lineId: 'l$i',
        text: sentences[i],
        translationAz: '',
        startMs: startMs,
        endMs: endMs,
      ),
    );
  }
  return lines;
}
