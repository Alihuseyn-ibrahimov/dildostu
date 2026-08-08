import 'package:dildostu/src/engine/location_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyFix', () {
    test('yaxşı fix dəqiq sayılır', () {
      expect(classifyFix(8), FixQuality.precise);
      expect(classifyFix(goodAccuracyMeters), FixQuality.precise);
    });

    test('orta fix təxmini sayılır (istifadə olunur)', () {
      expect(classifyFix(goodAccuracyMeters + 1), FixQuality.approximate);
      expect(classifyFix(maxUsableAccuracyMeters), FixQuality.approximate);
    });

    test('çox pis fix rədd edilir', () {
      // 2 km səhvlə "yaxınlıqdaki kafe" təsadüfi olur — səhv deməkdənsə heç nə.
      expect(classifyFix(maxUsableAccuracyMeters + 1), FixQuality.unusable);
      expect(classifyFix(2000), FixQuality.unusable);
    });

    test('bilinməyən dəqiqlik (0/mənfi) təxmini sayılır, rədd edilmir', () {
      expect(classifyFix(0), FixQuality.approximate);
      expect(classifyFix(-1), FixQuality.approximate);
    });
  });

  group('distanceMeters', () {
    test('eyni nöqtə sıfır verir', () {
      expect(distanceMeters(40.37, 49.83, 40.37, 49.83), closeTo(0, 0.1));
    });

    test('bilinən məsafəni düzgün hesablayır', () {
      // Bakıda ~0.001° enlik ≈ 111 m.
      final d = distanceMeters(40.370, 49.830, 40.371, 49.830);
      expect(d, closeTo(111, 3));
    });
  });

  group('isCacheUsable', () {
    final at = DateTime(2026, 8, 7, 10, 0);

    bool usable({
      Duration age = Duration.zero,
      double lat = 40.370,
      double lng = 49.830,
    }) =>
        isCacheUsable(
          cachedAt: at,
          cachedLat: 40.370,
          cachedLng: 49.830,
          now: at.add(age),
          currentLat: lat,
          currentLng: lng,
        );

    test('təzə və yerində olan keş işlədilir', () {
      expect(usable(age: const Duration(minutes: 1)), isTrue);
    });

    test('TTL keçəndən sonra keş etibarsızdır', () {
      expect(usable(age: placeCacheTtl + const Duration(seconds: 1)), isFalse);
    });

    test('istifadəçi uzaqlaşıbsa keş etibarsızdır', () {
      // ~111 m şimala — keş radiusundan (60 m) kənar.
      expect(usable(lat: 40.371), isFalse);
    });

    test('kiçik GPS titrəməsi keşi pozmur', () {
      // ~11 m — eyni yerdə dayanmış istifadəçinin normal titrəməsi.
      expect(usable(lat: 40.3701), isTrue);
    });
  });

  group('isAtPlace', () {
    test('yaxın yer üçün doğru', () {
      expect(isAtPlace(10), isTrue);
      expect(isAtPlace(60), isTrue);
    });

    test('uzaq yer üçün yalan', () {
      expect(isAtPlace(180), isFalse);
    });

    test('məsafə bilinmirsə yalan (uydurma iddia etmə)', () {
      expect(isAtPlace(null), isFalse);
    });
  });
}
