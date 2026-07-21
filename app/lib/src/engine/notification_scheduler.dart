import '../models/settings.dart';

const int _minDailyCount = 5;
const int _maxDailyCount = 10;

/// Verilmiş gün üçün bildiriş vaxtlarını hesablayır — oyanma/yatma
/// aralığında bərabər aralıqlarla (spec §4: sakit saatlara hörmət).
///
/// Pure funksiyadır (yan təsiri yoxdur) ki, cihazsız unit test oluna bilsin;
/// faktiki planlaşdırma (flutter_local_notifications) ayrı təbəqədədir.
List<DateTime> computeNotificationTimes(DateTime day, Settings settings) {
  if (settings.dailyNotificationCount < _minDailyCount ||
      settings.dailyNotificationCount > _maxDailyCount) {
    throw ArgumentError(
      'dailyNotificationCount $_minDailyCount-$_maxDailyCount aralığında olmalıdır',
    );
  }

  final wake = DateTime(day.year, day.month, day.day, settings.wakeHour, settings.wakeMinute);
  final sleep = DateTime(day.year, day.month, day.day, settings.sleepHour, settings.sleepMinute);
  if (!sleep.isAfter(wake)) {
    throw ArgumentError('sleep vaxtı wake vaxtından sonra olmalıdır (eyni gün daxilində)');
  }

  final totalMinutes = sleep.difference(wake).inMinutes;
  final n = settings.dailyNotificationCount;
  // Aralığı n+1 hissəyə bölüb daxili n sərhədini işlədirik ki, ilk bildiriş
  // dəqiq wake-də, sonuncusu dəqiq sleep-də olmasın (hər ikisi kənar haldır).
  final step = totalMinutes / (n + 1);

  return List<DateTime>.generate(
    n,
    (i) => wake.add(Duration(minutes: (step * (i + 1)).round())),
  );
}

/// Verilmiş anın istifadəçinin aktiv (oyanma-yatma) saatları daxilində
/// olub-olmadığını yoxlayır. Eyni günün wake/sleep saatlarına görə hesablanır.
bool isWithinActiveHours(DateTime moment, Settings settings) {
  final wake = DateTime(
    moment.year, moment.month, moment.day, settings.wakeHour, settings.wakeMinute,
  );
  final sleep = DateTime(
    moment.year, moment.month, moment.day, settings.sleepHour, settings.sleepMinute,
  );
  return !moment.isBefore(wake) && !moment.isAfter(sleep);
}
