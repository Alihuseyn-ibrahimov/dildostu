/// Sözlərin sinxronu — MÜTLƏQ (real) vaxtlar üzərində.
///
/// Vaxtlar manifestdən gəlir (`start_ms`, `word_ms`) — videonun öz audiosundan
/// (bax `content_gen/dildostu_content/lyrics_align.py`). Təxmin YOXDUR.
///
/// Bəzi sətirlərdə vaxt olmaya bilər (manifest videodakı sözlərlə uyğun gəlmirsə);
/// onlar heç vaxt vurğulanmır. Sözlər başlamamış intro-da heç nə rənglənmir.

library;

import '../models/song.dart';

/// JS pollinq + WebView gecikməsinin kiçik kompensasiyası.
const kDefaultSyncLeadMs = 120;

final lyricsWordPattern = RegExp(r"[A-Za-zÀ-ÿ']+");

int countWords(String text) => lyricsWordPattern.allMatches(text).length;

/// Ən azı bir sətirdə real vaxt varmı.
bool hasAnyTiming(List<SongLine> lines) =>
    lines.any((l) => l.startMs != null);

/// Oxunan sətir: vaxtı olan sətirlər arasında `start_ms`-i keçmiş sonuncu.
///
/// Intro (ilk sözə qədər) və uyğunlaşmamış sətirlər nəzərə alınmır → -1.
int activeLineIndex(
  List<SongLine> lines,
  int positionMs, {
  int syncLeadMs = kDefaultSyncLeadMs,
}) {
  if (!hasAnyTiming(lines) || positionMs < 0) return -1;
  final pos = positionMs + syncLeadMs;
  var active = -1;
  for (var i = 0; i < lines.length; i++) {
    final start = lines[i].startMs;
    if (start != null && pos >= start) active = i;
  }
  return active;
}

/// Sətir daxilində oxunan söz: vaxtı keçmiş SONUNCU söz.
int activeWordIndex(
  SongLine line,
  int positionMs, {
  int syncLeadMs = kDefaultSyncLeadMs,
}) {
  final start = line.startMs;
  if (start == null) return -1;
  final pos = positionMs + syncLeadMs;
  if (pos < start) return -1;

  final wordMs = line.wordMs;
  if (wordMs != null && wordMs.isNotEmpty) {
    for (var i = wordMs.length - 1; i >= 0; i--) {
      if (pos >= wordMs[i]) return i;
    }
    return -1;
  }

  final count = countWords(line.text);
  if (count == 0) return -1;
  final end = line.endMs ?? start;
  final span = end - start;
  if (span <= 0) return count - 1;
  final idx = ((pos - start) * count / span).floor();
  return idx.clamp(0, count - 1);
}
