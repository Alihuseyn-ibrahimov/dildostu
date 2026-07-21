import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/context_engine.dart';

const _prefsKey = 'dildostu.manual_context.v1';

/// İstifadəçinin "İndi haradayam?" seçimini saxlayır. Seçim 2 saat sonra
/// öz-özünə bitir ki, köhnə seçim yeni günü/yeri "yapışıb qalmasın".
class ManualContextRepository {
  ManualContextRepository._(this._prefs, this._stored);

  final SharedPreferences _prefs;
  ({String packId, DateTime setAt})? _stored;

  static const validity = Duration(hours: 2);

  static Future<ManualContextRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    ({String packId, DateTime setAt})? stored;
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      stored = (
        packId: decoded['pack_id'] as String,
        setAt: DateTime.parse(decoded['set_at'] as String),
      );
    }
    return ManualContextRepository._(prefs, stored);
  }

  Future<void> set(String packId, {required DateTime now}) async {
    _stored = (packId: packId, setAt: now);
    await _prefs.setString(
      _prefsKey,
      jsonEncode({'pack_id': packId, 'set_at': now.toIso8601String()}),
    );
  }

  Future<void> clear() async {
    _stored = null;
    await _prefs.remove(_prefsKey);
  }

  ManualSignal? currentSignal({required DateTime now}) {
    final stored = _stored;
    if (stored == null) return null;
    if (now.difference(stored.setAt) > validity) return null;
    return ManualSignal(packId: stored.packId);
  }
}
