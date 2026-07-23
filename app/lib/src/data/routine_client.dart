import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_summary.dart';

const _timeout = Duration(seconds: 15);

/// Rutin nümunələrini serverə göndərir və aqreqatı gətirir.
///
/// Toplama fon işidir — istifadəçini bloklamamalı. Ona görə hər iki metod xəta
/// halında səssiz keçir (postSample heç nə etmir, fetchSummary boş qaytarır).
class RoutineClient {
  RoutineClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<void> postSample({
    required String deviceId,
    required double lat,
    required double lng,
    required String placeType,
    String? packId,
  }) async {
    try {
      await _http
          .post(
            Uri.parse('$baseUrl/routine/sample'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': deviceId,
              'lat': lat,
              'lng': lng,
              'place_type': placeType,
              'pack_id': ?packId,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      // Fon işi — səssiz udulur.
    }
  }

  Future<List<PlaceSummary>> fetchSummary(String deviceId) async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/routine/summary/$deviceId'))
          .timeout(_timeout);
      if (resp.statusCode != 200) return const [];
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final places = (body['places'] as List).cast<Map<String, dynamic>>();
      return [for (final p in places) PlaceSummary.fromServerJson(p)];
    } catch (_) {
      return const [];
    }
  }
}
