import 'package:dildostu/src/engine/level_content.dart';
import 'package:dildostu/src/models/pack.dart';
import 'package:dildostu/src/models/user_profile.dart';
import 'package:dildostu/src/models/word.dart';
import 'package:flutter_test/flutter_test.dart';

Word _word(String text, int level) => Word(
      word: text,
      translationAz: '$text-az',
      ipa: '/$text/',
      example: '$text example.',
      exampleAz: '$text nümunə.',
      level: level,
    );

Pack _pack(List<Word> words) => Pack(
      packId: 'cafe',
      targetLang: 'en',
      uiLang: 'az',
      titleAz: 'Kafedə',
      words: words,
    );

void main() {
  group('ProficiencyLevel', () {
    test('üç səviyyəni tanıyır', () {
      expect(ProficiencyLevel.fromWire('beginner'), ProficiencyLevel.beginner);
      expect(ProficiencyLevel.fromWire('intermediate'),
          ProficiencyLevel.intermediate);
      expect(ProficiencyLevel.fromWire('advanced'), ProficiencyLevel.advanced);
    });

    test('söz səviyyəsi rəqəmi ilə uzlaşır', () {
      expect(ProficiencyLevel.beginner.wordLevel, 1);
      expect(ProficiencyLevel.intermediate.wordLevel, 2);
      expect(ProficiencyLevel.advanced.wordLevel, 3);
    });

    test('AZ adları var', () {
      expect(ProficiencyLevel.beginner.labelAz, 'Asan');
      expect(ProficiencyLevel.intermediate.labelAz, 'Orta');
      expect(ProficiencyLevel.advanced.labelAz, 'Çətin');
    });
  });

  group('wordsForLevel — statik paket fallback (spec §3)', () {
    test('tam uyğun səviyyənin sözlərini qaytarır', () {
      final pack = _pack([_word('a', 1), _word('b', 2), _word('c', 2)]);
      final result = wordsForLevel(pack, ProficiencyLevel.intermediate);
      expect(result.map((w) => w.word), ['b', 'c']);
    });

    test('səviyyədə söz yoxdursa ən yaxın AŞAĞI səviyyəyə düşür', () {
      // Çətin (3) yoxdur → Orta (2) qaytarılır.
      final pack = _pack([_word('a', 1), _word('b', 2)]);
      final result = wordsForLevel(pack, ProficiencyLevel.advanced);
      expect(result.map((w) => w.word), ['b']);
    });

    test('iki pillə aşağı düşə bilir', () {
      final pack = _pack([_word('a', 1)]);
      final result = wordsForLevel(pack, ProficiencyLevel.advanced);
      expect(result.map((w) => w.word), ['a']);
    });

    test('aşağıda heç nə yoxdursa yuxarı baxır', () {
      // Asan istənir, yalnız çətin söz var → boş qaytarmaqdansa onu ver.
      final pack = _pack([_word('c', 3)]);
      final result = wordsForLevel(pack, ProficiencyLevel.beginner);
      expect(result.map((w) => w.word), ['c']);
    });

    test('boş paket boş siyahı qaytarır', () {
      expect(wordsForLevel(_pack([]), ProficiencyLevel.beginner), isEmpty);
    });

    test('naməlum söz səviyyəsi (0, 9) sınmır', () {
      final pack = _pack([_word('x', 0), _word('y', 9)]);
      expect(wordsForLevel(pack, ProficiencyLevel.intermediate), isNotEmpty);
    });
  });
}
