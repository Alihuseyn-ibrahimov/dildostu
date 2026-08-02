import 'package:shared_preferences/shared_preferences.dart';

const _prefsPrefix = 'dildostu.geofence_notified.';

/// Hər geofence zonası üçün son bildiriş vaxtını saxlayır (kooldown yoxlaması
/// üçün) — istifadəçi eyni yerdə qalarkən hər 20 dəqiqədə bir bildiriş
/// gəlməsin.
class GeofenceCooldownRepository {
  GeofenceCooldownRepository(this._prefs);

  final SharedPreferences _prefs;

  static Future<GeofenceCooldownRepository> load() async {
    return GeofenceCooldownRepository(await SharedPreferences.getInstance());
  }

  DateTime? lastNotifiedAt(String zoneKey) {
    final iso = _prefs.getString('$_prefsPrefix$zoneKey');
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  Future<void> markNotified(String zoneKey, DateTime at) =>
      _prefs.setString('$_prefsPrefix$zoneKey', at.toIso8601String());
}
