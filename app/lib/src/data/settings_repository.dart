import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings.dart';

const _prefsKey = 'dildostu.settings.v1';

/// Settings-i cihazda saxlayır (shared_preferences, JSON blob).
class SettingsRepository {
  SettingsRepository._(this._prefs, this.current);

  final SharedPreferences _prefs;
  Settings current;

  static Future<SettingsRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final settings = raw == null
        ? Settings.defaults
        : Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return SettingsRepository._(prefs, settings);
  }

  Future<void> save(Settings settings) async {
    current = settings;
    await _prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
  }
}
