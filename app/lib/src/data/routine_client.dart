import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geofence_zone.dart';
import '../models/place_summary.dart';

const _timeout = Duration(seconds: 15);

/// Rutin nümunələrini serverə göndərir və aqreqatı gətirir.
///
/// Faza 2/3: bütün endpoint-lər `Authorization: Bearer <token>` tələb edir —
/// aqreqat artıq URL-dəki `device_id`-yə deyil, tokendəki istifadəçiyə görə
/// gəlir. Toplama fon işidir — istifadəçini bloklamamalı. Ona görə hər metod
/// xəta halında səssiz keçir (postSample heç nə etmir, fetch* boş qaytarır).
///
/// 401 gələndə (token vaxtı keçib/hesab silinib) `onUnauthorized` çağırılır —
/// main.dart bunu istifadəçini giriş ekranına qaytarmaq üçün işlədir.
class RoutineClient {
  RoutineClient({
    required this.baseUrl,
    required this.token,
    http.Client? httpClient,
    this.onUnauthorized,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String token;
  final void Function()? onUnauthorized;
  final http.Client _http;

  Map<String, String> get _authHeaders => {'Authorization': 'Bearer $token'};

  void _checkUnauthorized(http.Response resp) {
    if (resp.statusCode == 401) onUnauthorized?.call();
  }

  Future<void> postSample({
    required String deviceId,
    required double lat,
    required double lng,
    required String placeType,
    String? packId,
  }) async {
    try {
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/routine/sample'),
            headers: {..._authHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': deviceId,
              'lat': lat,
              'lng': lng,
              'place_type': placeType,
              'pack_id': ?packId,
            }),
          )
          .timeout(_timeout);
      _checkUnauthorized(resp);
    } catch (_) {
      // Fon işi — səssiz udulur.
    }
  }

  Future<List<PlaceSummary>> fetchSummary() async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/routine/summary'), headers: _authHeaders)
          .timeout(_timeout);
      _checkUnauthorized(resp);
      if (resp.statusCode != 200) return const [];
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final places = (body['places'] as List).cast<Map<String, dynamic>>();
      return [for (final p in places) PlaceSummary.fromServerJson(p)];
    } catch (_) {
      return const [];
    }
  }

  /// Tez-tez gedilən yerlər (geofence namizədləri). Xəta halında boş siyahı —
  /// çağıran tərəf (geofence yoxlaması) bu tick-də sakitcə heç nə etməməlidir.
  Future<List<GeofenceZone>> fetchGeofences() async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/routine/geofences'), headers: _authHeaders)
          .timeout(_timeout);
      _checkUnauthorized(resp);
      if (resp.statusCode != 200) return const [];
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final zones = (body['geofences'] as List).cast<Map<String, dynamic>>();
      return [for (final z in zones) GeofenceZone.fromServerJson(z)];
    } catch (_) {
      return const [];
    }
  }

  /// Hesab açılmazdan/giriş edilməzdən əvvəl bu cihazda toplanmış anonim
  /// nümunələri hesaba bağlayır. Bağlanan sətir sayını qaytarır (xəta → 0).
  Future<int> claimDevice(String deviceId) async {
    try {
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/routine/claim'),
            headers: {..._authHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(_timeout);
      _checkUnauthorized(resp);
      if (resp.statusCode != 200) return 0;
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      return body['claimed'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
