import 'dart:convert';

import 'package:dildostu/src/models/pack.dart';
import 'package:dildostu/src/models/word.dart';
import 'package:flutter_test/flutter_test.dart';

const _cafeJson = '''
{
  "pack_id": "cafe",
  "target_lang": "en",
  "ui_lang": "az",
  "title_az": "Kafedə",
  "words": [
    {
      "word": "coffee",
      "translation_az": "qəhvə",
      "ipa": "/ˈkɒfi/",
      "example": "I'd like a coffee.",
      "example_az": "Mənə qəhvə lazımdır.",
      "level": 1
    },
    {
      "word": "bill",
      "translation_az": "hesab",
      "ipa": "/bɪl/",
      "example": "Can I have the bill?",
      "example_az": "Hesabı gətirə bilərsiz?",
      "level": 2
    }
  ]
}
''';

void main() {
  group('Word.fromJson', () {
    test('bütün sahələri oxuyur', () {
      final word = Word.fromJson({
        'word': 'coffee',
        'translation_az': 'qəhvə',
        'ipa': '/ˈkɒfi/',
        'example': "I'd like a coffee.",
        'example_az': 'Mənə qəhvə lazımdır.',
        'level': 1,
      });
      expect(word.word, 'coffee');
      expect(word.translationAz, 'qəhvə');
      expect(word.ipa, '/ˈkɒfi/');
      expect(word.example, "I'd like a coffee.");
      expect(word.exampleAz, 'Mənə qəhvə lazımdır.');
      expect(word.level, 1);
    });
  });

  group('Pack.fromJson', () {
    test('paket meta + sözləri oxuyur', () {
      final pack = Pack.fromJson(jsonDecode(_cafeJson) as Map<String, dynamic>);
      expect(pack.packId, 'cafe');
      expect(pack.targetLang, 'en');
      expect(pack.uiLang, 'az');
      expect(pack.titleAz, 'Kafedə');
      expect(pack.words, hasLength(2));
      expect(pack.words.first.word, 'coffee');
      expect(pack.words[1].level, 2);
    });

    test('boş words siyahısına icazə verir (parsing səviyyəsində)', () {
      final pack = Pack.fromJson({
        'pack_id': 'x',
        'target_lang': 'en',
        'ui_lang': 'az',
        'title_az': 'X',
        'words': <dynamic>[],
      });
      expect(pack.words, isEmpty);
    });
  });
}
