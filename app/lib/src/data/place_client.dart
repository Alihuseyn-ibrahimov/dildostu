import 'dart:convert';

import 'package:http/http.dart' as http;

// Serverin öz Foursquare timeout-undan (6s, bax place_lookup.py
// _TIMEOUT_SECONDS) bir qədər böyük saxlanır ki, server cavab verməkdə
// olanda client vaxtından əvvəl kəsməsin.
const _timeout = Duration(seconds: 8);

/// Serverin tapdığı yer və ona uyğun söz paketi.
class PlaceResult {
  const PlaceResult({
    this.packId,
    this.name = '',
    this.category = '',
    this.distanceM,
  });

  /// Null ola bilər — server yer tapdı, amma tipi (məs. "Park") bizim
  /// paketlərə uyğun gəlmir. Bu halda `name`/`category` yenə doludur ki, UI
  /// istifadəçiyə nəyin tapıldığını göstərə bilsin.
  final String? packId;
  final String name;
  final String category;

  /// Yerin GPS mövqeyindən metr məsafəsi (server verirsə).
  final int? distanceM;

  bool get hasPack => packId != null && packId!.isNotEmpty;

  /// İstifadəçiyə göstərilən ad — ad yoxdursa kateqoriya.
  String get label => name.isNotEmpty ? name : category;
}

/// Koordinatı serverə göndərir; server Foursquare ilə yaxın yeri tapıb paket
/// kimliyini qaytarır (API açarı serverdə qalır — app-a düşmür).
///
/// Faza 2: endpoint `Authorization: Bearer <token>` tələb edir. Bütün xəta
/// halları (401/404/şəbəkə/timeout) sakitcə `null` qaytarır — çağıran tərəf
/// OSM fallback-a keçir və ya vaxt qaydasına düşür. 401-də əlavə olaraq
/// `onUnauthorized` çağırılır (main.dart giriş ekranına qaytarmaq üçün işlədir).
class PlaceClient {
  PlaceClient({
    required this.baseUrl,
    required this.token,
    http.Client? httpClient,
    this.onUnauthorized,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String token;
  final void Function()? onUnauthorized;
  final http.Client _http;

  Future<PlaceResult?> resolve(double lat, double lng) async {
    try {
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/place/resolve'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'lat': lat, 'lng': lng}),
          )
          .timeout(_timeout);
      if (resp.statusCode == 401) onUnauthorized?.call();
      if (resp.statusCode != 200) return null;
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final packId = body['pack_id'] as String?;
      final name = (body['name'] as String?) ?? '';
      final category = (body['category'] as String?) ?? '';
      // Paket yoxdursa da nəticə qaytarılır (yalnız hamısı boşdursa null) —
      // "Park tapıldı, amma paketi yoxdur" halı UI-da görünməlidir.
      if ((packId == null || packId.isEmpty) &&
          name.isEmpty &&
          category.isEmpty) {
        return null;
      }
      return PlaceResult(
        packId: (packId != null && packId.isNotEmpty) ? packId : null,
        name: name,
        category: category,
        distanceM: (body['distance_m'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
