import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/place_client.dart';
import '../engine/osm_place_mapping.dart';

const _overpassUrl = 'https://overpass-api.de/api/interpreter';
// Böyük məkanların (ticarət mərkəzi, hava limanı) OSM node-u GPS mövqeyindən
// xeyli aralı ola bilər — radius geniş tutulur ki, yer tanına bilsin.
const _searchRadiusMeters = 120;
const _requestTimeout = Duration(seconds: 8);

/// Cihazın GPS-i ilə yaxınlıqdakı yerin tipini müəyyənləşdirir.
///
/// Əsas mənbə: DilDostu serveri (Foursquare) — AZ örtüyü güclü, etibarlı.
/// Server yer tapmasa/əlçatmaz olsa OpenStreetMap Overpass ehtiyat qalır.
/// Bütün xəta halları (icazə/internet/timeout) sakitcə `null` qaytarır —
/// ContextEngine bu halda vaxt qaydasına düşür, app sınmır.
class LocationService {
  LocationService({http.Client? httpClient, PlaceClient? placeClient})
      : _http = httpClient ?? http.Client(),
        _place = placeClient ??
            PlaceClient(baseUrl: AppConfig.serverBaseUrl);

  final http.Client _http;
  final PlaceClient _place;

  Future<String?> resolveNearbyPackId() async =>
      (await resolveNearbySample())?.packId;

  /// Rutin toplama üçün: koordinat + təyin olunmuş pack + yerin adı. Bütün xəta
  /// halları (icazə/GPS/şəbəkə/timeout) sakitcə `null` qaytarır.
  Future<({double lat, double lng, String packId, String place})?>
      resolveNearbySample() async {
    try {
      if (!await _hasUsablePermission()) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _requestTimeout,
        ),
      );

      // 1) Əsas: server (Foursquare).
      final server = await _place.resolve(position.latitude, position.longitude);
      if (server != null) {
        return (
          lat: position.latitude,
          lng: position.longitude,
          packId: server.packId,
          place: server.name.isNotEmpty ? server.name : server.category,
        );
      }

      // 2) Ehtiyat: OpenStreetMap.
      final tags = await _queryNearbyTags(position.latitude, position.longitude)
          .timeout(_requestTimeout);
      if (tags == null) return null;
      final packId = packIdForOsmTags(tags);
      if (packId == null) return null;
      return (
        lat: position.latitude,
        lng: position.longitude,
        packId: packId,
        place: tags['name'] ?? '',
      );
    } catch (_) {
      // GPS/şəbəkə xətası, timeout və s. — sakitcə imtina et.
      return null;
    }
  }

  Future<bool> _hasUsablePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// "İndi yoxla" diaqnostikası — hər mərhələni insanoxunaqlı sətir kimi qaytarır
  /// (koordinat, server nəticəsi, OSM ehtiyatı) ki, problem harada olduğu görünsün.
  Future<String> diagnose() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Məkan icazəsi yoxdur (${permission.name}). Ayarlardan icazə ver.';
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _requestTimeout,
        ),
      );
      final coord =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      final server = await _place.resolve(position.latitude, position.longitude);
      if (server != null) {
        final label = server.name.isNotEmpty ? server.name : server.category;
        return 'Məkan: $coord\n'
            'Tapıldı (server): $label\n'
            'Kateqoriya: ${server.category} → paket: ${server.packId}';
      }

      // Server nəticə vermədi — OSM ehtiyatını yoxla.
      final tags = await _queryNearbyTags(position.latitude, position.longitude)
          .timeout(_requestTimeout);
      if (tags == null) {
        return 'Məkan alındı: $coord\n'
            'Nə serverdə, nə OSM-də ${_searchRadiusMeters}m radiusda qeydiyyatlı '
            'yer tapılmadı (yəqin evdəsən). Kafe/market kimi yerdə yenidən yoxla.';
      }
      final tagStr =
          tags.entries.take(3).map((e) => '${e.key}=${e.value}').join(', ');
      final packId = packIdForOsmTags(tags);
      return 'Məkan: $coord\nOSM tapdı: $tagStr\n'
          'Paket: ${packId ?? "bu tip paketimizdə yoxdur"}';
    } catch (e) {
      return 'Məkan alınmadı (GPS/internet xətası). Yenidən cəhd et.';
    }
  }

  /// Arxa fon (always) icazəsini tələb edir. Əvvəl ön-plan (whileInUse), sonra
  /// yenidən sorğu ilə `always`. Android 11+ "Həmişə icazə ver"i tək dialoqdan
  /// verə bilmir — o halda `false` qaytarır, UI istifadəçini Ayarlara yönləndirir.
  Future<bool> ensureBackgroundPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse) {
      // İkinci sorğu — bəzi cihazlarda "always"a yüksəldir.
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always;
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  /// Arxa fon (always) icazəsi verilibmi — sorğu ETMƏDƏN yoxlayır. App açılışda
  /// rutin toplamanı yenidən qeyd etmək üçün.
  Future<bool> hasBackgroundPermission() async =>
      (await Geolocator.checkPermission()) == LocationPermission.always;

  Future<Map<String, String>?> _queryNearbyTags(double lat, double lon) async {
    final query = '[out:json][timeout:5];'
        'node(around:$_searchRadiusMeters,$lat,$lon)'
        '[~"^(amenity|shop|tourism|aeroway|railway|public_transport)\$"~"."];'
        'out tags 1;';
    final response = await _http.post(
      Uri.parse(_overpassUrl),
      body: {'data': query},
    );
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>?;
    if (elements == null || elements.isEmpty) return null;

    final tags = (elements.first as Map<String, dynamic>)['tags'];
    if (tags is! Map) return null;
    return tags.map((key, value) => MapEntry(key.toString(), value.toString()));
  }
}
