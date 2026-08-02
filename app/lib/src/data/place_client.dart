import 'dart:convert';

import 'package:http/http.dart' as http;

const _timeout = Duration(seconds: 8);

/// Serverin tapdığı yer və ona uyğun söz paketi.
class PlaceResult {
  const PlaceResult({required this.packId, this.name = '', this.category = ''});

  final String packId;
  final String name;
  final String category;
}

/// Koordinatı serverə göndərir; server Foursquare ilə yaxın yeri tapıb paket
/// kimliyini qaytarır (API açarı serverdə qalır — app-a düşmür).
///
/// Bütün xəta halları (404 = yer yoxdur, şəbəkə, timeout) sakitcə `null`
/// qaytarır — çağıran tərəf OSM fallback-a keçir və ya vaxt qaydasına düşür.
class PlaceClient {
  PlaceClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<PlaceResult?> resolve(double lat, double lng) async {
    try {
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/place/resolve'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'lat': lat, 'lng': lng}),
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final packId = body['pack_id'] as String?;
      if (packId == null || packId.isEmpty) return null;
      return PlaceResult(
        packId: packId,
        name: (body['name'] as String?) ?? '',
        category: (body['category'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
