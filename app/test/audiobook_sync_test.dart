import 'package:dildostu/src/engine/audiobook_sync.dart';
import 'package:dildostu/src/engine/lyrics_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitChapterSentences', () {
    test('cümlələri ayırır', () {
      expect(
        splitChapterSentences('Uno. Dos. Tres.'),
        ['Uno.', 'Dos.', 'Tres.'],
      );
    });

    test('paraqraf boşluqlarını ayırır', () {
      expect(
        splitChapterSentences('Primera frase.\n\nSegunda frase.'),
        ['Primera frase.', 'Segunda frase.'],
      );
    });
  });

  group('buildAudiobookLines', () {
    test('sözlərə görə vaxt paylayır', () {
      // 4 + 2 = 6 söz, 60s → birinci cümlə ~40s, ikinci ~20s
      final lines = buildAudiobookLines(
        'One two three four. Five six.',
        const Duration(seconds: 60),
      );
      expect(lines.length, 2);
      expect(lines[0].startMs, 0);
      expect(lines[0].endMs, 40000);
      expect(lines[1].startMs, 40000);
      expect(lines[1].endMs, 60000);
    });

    test('aktiv sətir və söz sinxronu işləyir', () {
      final lines = buildAudiobookLines(
        'Hello world. Goodbye moon.',
        const Duration(seconds: 10),
      );
      expect(activeLineIndex(lines, 0), 0);
      expect(activeLineIndex(lines, 3000), 0);
      expect(activeLineIndex(lines, 7000), 1);
      expect(activeWordIndex(lines[0], 1200), 0);
      expect(activeWordIndex(lines[0], 4500), 1);
    });
  });
}
