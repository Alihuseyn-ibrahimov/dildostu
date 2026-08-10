import 'package:dildostu/src/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationDiagnostics', () {
    test('hər şey qaydasındadırsa problem yoxdur', () {
      const d = NotificationDiagnostics(
        pendingCount: 6,
        canScheduleExact: true,
        lastError: null,
      );
      expect(d.hasProblem, isFalse);
      expect(d.summary, contains('6'));
    });

    test('planlaşdırılmış bildiriş yoxdursa problem sayılır', () {
      // ƏSAS HAL: icazələr açıq görünür, amma OS-də növbədə heç nə yoxdur —
      // "bildiriş gəlmir" şikayətinin ən çox rast gəlinən səbəbi budur.
      const d = NotificationDiagnostics(
        pendingCount: 0,
        canScheduleExact: true,
        lastError: null,
      );
      expect(d.hasProblem, isTrue);
      expect(d.summary.toLowerCase(), contains('yoxdur'));
    });

    test('xəta varsa problem sayılır və mətndə görünür', () {
      const d = NotificationDiagnostics(
        pendingCount: 6,
        canScheduleExact: true,
        lastError: 'PlatformException(exact_alarms_not_permitted)',
      );
      expect(d.hasProblem, isTrue);
      expect(d.summary, contains('exact_alarms_not_permitted'));
    });

    test('dəqiq alarm icazəsi yoxdursa problem sayılır', () {
      const d = NotificationDiagnostics(
        pendingCount: 6,
        canScheduleExact: false,
        lastError: null,
      );
      expect(d.hasProblem, isTrue);
      expect(d.summary.toLowerCase(), contains('alarm'));
    });
  });
}
