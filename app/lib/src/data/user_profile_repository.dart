import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

const _prefsKey = 'dildostu.user_profile.v1';

/// İstifadəçi profilini cihazda saxlayır. Profil yoxdursa onboarding lazımdır.
class UserProfileRepository {
  UserProfileRepository._(this._prefs, this.current);

  final SharedPreferences _prefs;
  UserProfile? current;

  bool get isOnboarded => current != null;

  static Future<UserProfileRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final profile = raw == null
        ? null
        : UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return UserProfileRepository._(prefs, profile);
  }

  Future<void> save(UserProfile profile) async {
    current = profile;
    await _prefs.setString(_prefsKey, jsonEncode(profile.toJson()));
  }

  /// Yaddaşdakı profili silir. Server profil qaytarmadıqda (yeni hesab və ya
  /// eyni cihazda fərqli istifadəçi) köhnə profilin sızmasının qarşısını alır.
  Future<void> clear() async {
    current = null;
    await _prefs.remove(_prefsKey);
  }
}
