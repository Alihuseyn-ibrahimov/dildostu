import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/live_message.dart';

const _prefsKey = 'dildostu.day_plan.v1';

/// Gündəlik AI missiyasının cihaz keşi — gündə bir dəfə `/day-plan` çağırışı.
class DayPlanCacheRepository {
  DayPlanCacheRepository._(this._prefs);

  final SharedPreferences _prefs;

  static Future<DayPlanCacheRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DayPlanCacheRepository._(prefs);
  }

  /// [dateKey] — `dayPlanDateKey()` formatında (YYYY-MM-DD).
  ({String dateKey, List<LiveMessage> messages})? read(String dateKey) {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if ((json['date'] as String?) != dateKey) return null;
    final list = (json['messages'] as List).cast<Map<String, dynamic>>();
    return (
      dateKey: dateKey,
      messages: [for (final m in list) LiveMessage.fromCacheJson(m)],
    );
  }

  Future<void> save(String dateKey, List<LiveMessage> messages) async {
    await _prefs.setString(
      _prefsKey,
      jsonEncode({
        'date': dateKey,
        'messages': [for (final m in messages) m.toCacheJson()],
      }),
    );
  }
}
