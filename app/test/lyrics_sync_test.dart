import 'package:dildostu/src/engine/lyrics_sync.dart';
import 'package:dildostu/src/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

const _lines = [
  SongLine(
    lineId: 'l1',
    text: 'Para bailar La Bamba',
    translationAz: 'Bamba rəqsi üçün',
    startMs: 5620,
    endMs: 7960,
    wordMs: [5620, 6620, 7040, 7440],
  ),
  SongLine(
    lineId: 'l2',
    text: 'Se necessita una poca de gracia',
    translationAz: 'Bir az lütf lazımdır',
    startMs: 11260,
    endMs: 16000,
    wordMs: [11260, 11760, 12880, 13320, 13680, 14120],
  ),
];

void main() {
  group('activeLineIndex', () {
    test('sözlər başlamamış heç nə vurğulanmır (intro)', () {
      expect(activeLineIndex(_lines, 3000, syncLeadMs: 0), -1);
      expect(activeLineIndex(_lines, 5619, syncLeadMs: 0), -1);
    });

    test('birinci sətir öz real anında başlayır', () {
      expect(activeLineIndex(_lines, 5620, syncLeadMs: 0), 0);
    });

    test('növbəti sətrin anında ona keçir', () {
      expect(activeLineIndex(_lines, 11300, syncLeadMs: 0), 1);
    });

    test('qismən vaxtlı sətirlərdə sinxron işləyir', () {
      const partial = [
        SongLine(
          lineId: 'l1',
          text: 'A',
          translationAz: 'a',
          startMs: 1000,
        ),
        SongLine(
          lineId: 'l2',
          text: 'B',
          translationAz: 'b',
        ),
        SongLine(
          lineId: 'l3',
          text: 'C',
          translationAz: 'c',
          startMs: 5000,
        ),
      ];
      expect(hasAnyTiming(partial), isTrue);
      expect(activeLineIndex(partial, 3000, syncLeadMs: 0), 0);
      expect(activeLineIndex(partial, 4500, syncLeadMs: 0), 0);
      expect(activeLineIndex(partial, 5100, syncLeadMs: 0), 2);
    });

    test('heç bir sətirdə vaxt yoxdursa sinxron sönür', () {
      const noTiming = [
        SongLine(lineId: 'l1', text: 'Aaa', translationAz: 'a'),
      ];
      expect(hasAnyTiming(noTiming), isFalse);
      expect(activeLineIndex(noTiming, 99999), -1);
    });
  });

  group('activeWordIndex', () {
    test('hər söz öz real anında vurğulanır', () {
      expect(activeWordIndex(_lines[0], 5620, syncLeadMs: 0), 0);
      expect(activeWordIndex(_lines[0], 6700, syncLeadMs: 0), 1);
      expect(activeWordIndex(_lines[0], 7500, syncLeadMs: 0), 3);
    });

    test('vaxtsız sətirdə söz vurğulanmır', () {
      const line = SongLine(lineId: 'l1', text: 'hello', translationAz: 'x');
      expect(activeWordIndex(line, 99999), -1);
    });
  });

  test('İspan hərfləri tanınır', () {
    expect(countWords('Yo no fuí, yo no fuí'), 6);
  });
}
