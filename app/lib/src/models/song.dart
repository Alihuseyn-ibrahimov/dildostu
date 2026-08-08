/// Mahnı modelləri — serverin `/music` manifestinə uyğundur.
library;

class SongLine {
  const SongLine({
    required this.lineId,
    required this.text,
    required this.translationAz,
    this.startMs,
    this.endMs,
    this.wordMs,
  });

  final String lineId;
  final String text;
  final String translationAz;

  /// Videoda bu sətrin oxunmağa başladığı an (mütləq ms).
  final int? startMs;

  /// Növbəti sətrin başlanğıcı (mütləq ms).
  final int? endMs;

  /// Sətirdəki hər sözün öz başlanğıcı (mütləq ms) — real audio vaxtları.
  final List<int>? wordMs;

  factory SongLine.fromServerJson(Map<String, dynamic> json) => SongLine(
        lineId: json['line_id'] as String,
        text: json['text'] as String,
        translationAz: json['translation_az'] as String,
        startMs: (json['start_ms'] as num?)?.toInt(),
        endMs: (json['end_ms'] as num?)?.toInt(),
        wordMs: (json['word_ms'] as List?)
            ?.map((v) => (v as num).toInt())
            .toList(),
      );
}

class Song {
  const Song({
    required this.songId,
    required this.title,
    required this.artist,
    required this.youtubeId,
    required this.level,
    required this.lines,
    this.lang = 'en',
  });

  final String songId;
  final String title;
  final String artist;
  final String youtubeId;
  final String level;
  final List<SongLine> lines;
  final String lang;

  factory Song.fromServerJson(Map<String, dynamic> json) => Song(
        songId: json['song_id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        youtubeId: json['youtube_id'] as String,
        level: json['level'] as String? ?? 'beginner',
        lang: json['lang'] as String? ?? 'en',
        lines: [
          for (final l in (json['lines'] as List? ?? const []))
            SongLine.fromServerJson(l as Map<String, dynamic>),
        ],
      );
}
