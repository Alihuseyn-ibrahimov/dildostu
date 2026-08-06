/// Mahnı modelləri — serverin `/music` manifestinə uyğundur.
///
/// Audio bizdə saxlanmır — `youtubeId` bizim serverin `/music/embed/{id}`
/// səhifəsi vasitəsilə proqram daxilində embed olunur (bax
/// `music_screen.dart`-dakı `SongPlayerScreen` qeydi, 2026-08-05). Hər
/// sətrin AZ tərcüməsi manifestə daxildir ki, dinləyərkən dərhal görünsün;
/// sözə toxunub ayrıca mənasına baxmaq üçün mövcud `/word-lookup` işlədilir
/// (audiobook-dakı eyni mexanizm).
library;

class SongLine {
  const SongLine({
    required this.lineId,
    required this.text,
    required this.translationAz,
  });

  final String lineId;
  final String text;
  final String translationAz;

  factory SongLine.fromServerJson(Map<String, dynamic> json) => SongLine(
        lineId: json['line_id'] as String,
        text: json['text'] as String,
        translationAz: json['translation_az'] as String,
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

  /// Mahnının dili (`target_lang` ilə uzlaşır) — audiobook-dakı `lang`
  /// sahəsi ilə eyni məqsəd: app bunu `profile.targetLang`-a görə süzür.
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
