import 'time_context_rule.dart';

/// Gündəlik missiya üçün 3 kontekst paketi seçir (vaxt qaydası ilə).
///
/// `pickPackForSlot` ilə eyni məntiq — səhər/axşam prioritet, ortada fırlanma.
List<String> pickDayPlanPackIds(List<String> availablePackIds, DateTime now) {
  if (availablePackIds.isEmpty) return const [];
  if (availablePackIds.length <= 3) return List<String>.from(availablePackIds);

  const totalSlots = 3;
  final picks = <String>[];
  for (var i = 0; i < totalSlots; i++) {
    picks.add(pickPackForSlot(i, totalSlots, availablePackIds));
  }
  // Təkrarları sil, sıranı qoru.
  final unique = <String>[];
  for (final id in picks) {
    if (!unique.contains(id)) unique.add(id);
  }
  if (unique.length >= 3) return unique.take(3).toList();

  for (final id in availablePackIds) {
    if (unique.length >= 3) break;
    if (!unique.contains(id)) unique.add(id);
  }
  return unique;
}

/// API-yə göndəriləcək ISO tarix (YYYY-MM-DD).
String dayPlanDateKey(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';
