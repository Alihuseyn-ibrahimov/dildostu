import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_profile.dart';

const _timeout = Duration(seconds: 8);

/// `/profile` cavabının nəticəsi — şəbəkə xətası ilə boş profili ayırır.
class ProfileFetchOutcome {
  const ProfileFetchOutcome({
    required this.reachedServer,
    this.profile,
  });

  /// Server HTTP cavab veribsə true; timeout/şəbəkə xətasında false.
  final bool reachedServer;

  /// Server profil qaytardıqda dolu; `profile: null` cavabında null.
  final UserProfile? profile;
}

/// Serverdə saxlanan istifadəçi profili (Faza 2 — "hər istifadəçi üçün ayrıca
/// AI yanaşması"). Fərqli fiziki cihazlarda eyni hesab, yaxud eyni cihazda
/// fərqli hesablar girsə də profil düzgün istifadəçiyə bağlı qalır.
///
/// Bütün xəta halları (401/şəbəkə) sakitcə `null`/`false` qaytarır — çağıran
/// tərəf (main.dart) 401-i ayrıca `onUnauthorized` ilə tutub çıxış edir.
class ProfileClient {
  ProfileClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<ProfileFetchOutcome> fetchOutcome(String token) async {
    try {
      final resp = await _http
          .get(
            Uri.parse('$baseUrl/profile'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        return const ProfileFetchOutcome(reachedServer: false);
      }
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final raw = body['profile'] as Map<String, dynamic>?;
      return ProfileFetchOutcome(
        reachedServer: true,
        profile: raw == null ? null : UserProfile.fromJson(raw),
      );
    } catch (_) {
      return const ProfileFetchOutcome(reachedServer: false);
    }
  }

  Future<UserProfile?> fetch(String token) async {
    final outcome = await fetchOutcome(token);
    return outcome.profile;
  }

  Future<bool> save(String token, UserProfile profile) async {
    try {
      final resp = await _http
          .put(
            Uri.parse('$baseUrl/profile'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'profile': profile.toServerJson()}),
          )
          .timeout(_timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
