/// Bir öyrənmə sözü — asset paketindəki JSON obyektinə uyğundur (spec §3.1).
class Word {
  const Word({
    required this.word,
    required this.translationAz,
    required this.ipa,
    required this.example,
    required this.exampleAz,
    required this.level,
  });

  final String word;
  final String translationAz;
  final String ipa;
  final String example;
  final String exampleAz;
  final int level;

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'] as String,
      translationAz: json['translation_az'] as String,
      ipa: json['ipa'] as String,
      example: json['example'] as String,
      exampleAz: json['example_az'] as String,
      level: json['level'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'translation_az': translationAz,
        'ipa': ipa,
        'example': example,
        'example_az': exampleAz,
        'level': level,
      };
}
