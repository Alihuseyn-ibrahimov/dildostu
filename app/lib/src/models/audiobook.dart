/// Səsli kitab modelləri — serverin `/audiobooks` manifestinə uyğundur.
///
/// Mətn (`text`) manifestə daxildir ki, dinləyərkən ekranda göstərilsin və
/// sözə toxunub mənasına baxmaq mümkün olsun.
library;

class AudiobookChapter {
  const AudiobookChapter({
    required this.chapterId,
    required this.titleEn,
    required this.duration,
    required this.sizeBytes,
    required this.text,
  });

  final String chapterId;
  final String titleEn;
  final Duration duration;
  final int sizeBytes;
  final String text;

  factory AudiobookChapter.fromServerJson(Map<String, dynamic> json) =>
      AudiobookChapter(
        chapterId: json['chapter_id'] as String,
        titleEn: json['title_en'] as String,
        // Serverdə saniyə (ondalıqlı) gəlir — millisaniyəyə çeviririk.
        duration: Duration(
          milliseconds: ((json['duration_sec'] as num) * 1000).round(),
        ),
        sizeBytes: json['size_bytes'] as int,
        text: json['text'] as String? ?? '',
      );

  /// "3:07" formatında oxunaqlı uzunluq.
  String get durationLabel {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class Audiobook {
  const Audiobook({
    required this.bookId,
    required this.titleEn,
    required this.titleAz,
    required this.author,
    required this.source,
    required this.level,
    required this.chapters,
    this.lang = 'en',
  });

  final String bookId;
  final String titleEn;
  final String titleAz;
  final String author;

  /// İctimai domen mənbəyi — UI-da göstərilir (attribution).
  final String source;
  final String level;
  final List<AudiobookChapter> chapters;

  /// Kitabın dili (`target_lang` ilə uzlaşır). Köhnə manifestdə bu sahə
  /// yoxdursa İngilisə düşür (bax 2026-08-04-multilanguage-russian-design.md).
  final String lang;

  factory Audiobook.fromServerJson(Map<String, dynamic> json) => Audiobook(
        bookId: json['book_id'] as String,
        titleEn: json['title_en'] as String,
        titleAz: json['title_az'] as String? ?? json['title_en'] as String,
        author: json['author'] as String? ?? '',
        source: json['source'] as String? ?? '',
        level: json['level'] as String? ?? 'beginner',
        lang: json['lang'] as String? ?? 'en',
        chapters: [
          for (final c in (json['chapters'] as List? ?? const []))
            AudiobookChapter.fromServerJson(c as Map<String, dynamic>),
        ],
      );

  Duration get totalDuration =>
      chapters.fold(Duration.zero, (sum, c) => sum + c.duration);
}
