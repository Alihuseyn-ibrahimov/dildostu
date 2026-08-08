/// Gündəlik proaktiv chat bildirişlərinin sayı və sabit vaxtları.
const int chatNudgesPerDay = 3;
const int chatMorningHour = 8;
const int chatLunchHour = 13;
const int chatEveningHour = 22;

/// Səhər 08:00, nahar 13:00, axşam 22:00 — yerli vaxt.
List<DateTime> computeChatNudgeTimes(DateTime day) {
  return [
    DateTime(day.year, day.month, day.day, chatMorningHour),
    DateTime(day.year, day.month, day.day, chatLunchHour),
    DateTime(day.year, day.month, day.day, chatEveningHour),
  ];
}

/// [now]-dan sonrakı chat slotları — bugün + növbəti günlər (sabah üçün plan).
List<DateTime> computeUpcomingChatNudgeTimes(
  DateTime now, {
  int dayCount = 2,
}) {
  final slots = <DateTime>[];
  final today = DateTime(now.year, now.month, now.day);
  for (var d = 0; d < dayCount; d++) {
    final day = today.add(Duration(days: d));
    for (final t in computeChatNudgeTimes(day)) {
      if (t.isAfter(now)) slots.add(t);
    }
  }
  return slots;
}
