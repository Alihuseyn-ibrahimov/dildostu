import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'dildostu.device_id.v1';

/// Anonim cihaz identifikatoru — rutin nümunələrini serverdə açarlamaq üçün.
/// PII deyil; ilk açılışda təsadüfi yaradılır, cihazda saxlanılır.
class DeviceIdRepository {
  DeviceIdRepository._(this.deviceId);

  final String deviceId;

  static Future<DeviceIdRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await prefs.setString(_prefsKey, id);
    }
    return DeviceIdRepository._(id);
  }

  /// 32 simvolluq təsadüfi hex sətri (Random.secure — uuid asılılığı gətirmir).
  static String _generateId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
