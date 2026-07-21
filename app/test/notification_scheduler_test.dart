import 'package:dildostu/src/engine/notification_scheduler.dart';
import 'package:dildostu/src/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 7, 21); // istənilən gün, saat 00:00

  group('computeNotificationTimes', () {
    test('tələb olunan sayda vaxt yaradır', () {
      const settings = Settings(
        wakeHour: 8,
        wakeMinute: 0,
        sleepHour: 23,
        sleepMinute: 0,
        dailyNotificationCount: 6,
      );
      final times = computeNotificationTimes(day, settings);
      expect(times, hasLength(6));
    });

    test('bütün vaxtlar oyanma/yatma aralığındadır', () {
      const settings = Settings(
        wakeHour: 8,
        wakeMinute: 0,
        sleepHour: 22,
        sleepMinute: 30,
        dailyNotificationCount: 8,
      );
      final times = computeNotificationTimes(day, settings);
      final wake = DateTime(2026, 7, 21, 8, 0);
      final sleep = DateTime(2026, 7, 21, 22, 30);
      for (final t in times) {
        expect(t.isBefore(wake), isFalse);
        expect(t.isAfter(sleep), isFalse);
      }
    });

    test('vaxtlar artan sıradadır və təkrarlanmır', () {
      const settings = Settings(
        wakeHour: 7,
        wakeMinute: 30,
        sleepHour: 23,
        sleepMinute: 0,
        dailyNotificationCount: 10,
      );
      final times = computeNotificationTimes(day, settings);
      for (var i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isTrue);
      }
    });

    test('minimum 5, maksimum 10 bildiriş sayına icazə verir', () {
      const tooFew = Settings(
        wakeHour: 8,
        wakeMinute: 0,
        sleepHour: 22,
        sleepMinute: 0,
        dailyNotificationCount: 2,
      );
      expect(() => computeNotificationTimes(day, tooFew), throwsArgumentError);

      const tooMany = Settings(
        wakeHour: 8,
        wakeMinute: 0,
        sleepHour: 22,
        sleepMinute: 0,
        dailyNotificationCount: 15,
      );
      expect(() => computeNotificationTimes(day, tooMany), throwsArgumentError);
    });

    test('yatma vaxtı oyanma vaxtından tez olarsa xəta atır', () {
      const bad = Settings(
        wakeHour: 22,
        wakeMinute: 0,
        sleepHour: 8,
        sleepMinute: 0,
        dailyNotificationCount: 5,
      );
      expect(() => computeNotificationTimes(day, bad), throwsArgumentError);
    });
  });

  group('isWithinActiveHours', () {
    const settings = Settings(
      wakeHour: 8,
      wakeMinute: 0,
      sleepHour: 22,
      sleepMinute: 0,
      dailyNotificationCount: 6,
    );

    test('aralıqdakı vaxt üçün true', () {
      expect(isWithinActiveHours(DateTime(2026, 7, 21, 14, 0), settings), isTrue);
    });

    test('gecə yarısı üçün false (sakit saat)', () {
      expect(isWithinActiveHours(DateTime(2026, 7, 21, 2, 0), settings), isFalse);
    });
  });
}
