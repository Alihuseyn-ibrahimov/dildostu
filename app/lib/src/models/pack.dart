import 'word.dart';

/// Bir kontekst söz paketi (kafe, aeroport və s.) — asset JSON faylına uyğun.
class Pack {
  const Pack({
    required this.packId,
    required this.targetLang,
    required this.uiLang,
    required this.titleAz,
    required this.words,
  });

  final String packId;
  final String targetLang;
  final String uiLang;
  final String titleAz;
  final List<Word> words;

  factory Pack.fromJson(Map<String, dynamic> json) {
    final rawWords = (json['words'] as List<dynamic>);
    return Pack(
      packId: json['pack_id'] as String,
      targetLang: json['target_lang'] as String,
      uiLang: json['ui_lang'] as String,
      titleAz: json['title_az'] as String,
      words: rawWords
          .map((w) => Word.fromJson(w as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
