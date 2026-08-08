import 'word.dart';

/// Serverdən (və ya statik fallback-dan) gələn bir canlı mesaj.
/// Söz məlumatı + AI-nin dostcasına sətri + mənbə (canlı/statik).
class LiveMessage {
  const LiveMessage({
    required this.packId,
    required this.word,
    required this.translationAz,
    required this.ipa,
    required this.example,
    required this.exampleAz,
    required this.aiLine,
    required this.level,
    required this.isLive,
  });

  final String packId;
  final String word;
  final String translationAz;
  final String ipa;
  final String example;
  final String exampleAz;
  final String aiLine;
  final int level;

  /// true → serverdən (canlı AI); false → statik paketdən (offline fallback).
  final bool isLive;

  factory LiveMessage.fromServerJson(Map<String, dynamic> json) => LiveMessage(
        packId: json['pack_id'] as String,
        word: json['word'] as String,
        translationAz: json['translation_az'] as String,
        ipa: json['ipa'] as String,
        example: json['example'] as String,
        exampleAz: json['example_az'] as String,
        aiLine: json['ai_line'] as String,
        level: json['level'] as int,
        isLive: true,
      );

  /// Statik paket sözündən fallback mesaj qur.
  factory LiveMessage.fromWord(Word w, String packId, {String? aiLine}) =>
      LiveMessage(
        packId: packId,
        word: w.word,
        translationAz: w.translationAz,
        ipa: w.ipa,
        example: w.example,
        exampleAz: w.exampleAz,
        aiLine: aiLine ?? 'Bu sözü öyrənək 👇',
        level: w.level,
        isLive: false,
      );

  /// Cihaz keşindən oxuma (`DayPlanCacheRepository`).
  factory LiveMessage.fromCacheJson(Map<String, dynamic> json) => LiveMessage(
        packId: json['pack_id'] as String,
        word: json['word'] as String,
        translationAz: json['translation_az'] as String,
        ipa: json['ipa'] as String,
        example: json['example'] as String,
        exampleAz: json['example_az'] as String,
        aiLine: json['ai_line'] as String,
        level: json['level'] as int,
        isLive: json['is_live'] as bool? ?? true,
      );

  Map<String, dynamic> toCacheJson() => {
        'pack_id': packId,
        'word': word,
        'translation_az': translationAz,
        'ipa': ipa,
        'example': example,
        'example_az': exampleAz,
        'ai_line': aiLine,
        'level': level,
        'is_live': isLive,
      };

  Word toWord() => Word(
        word: word,
        translationAz: translationAz,
        ipa: ipa,
        example: example,
        exampleAz: exampleAz,
        level: level,
      );
}
