import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../data/place_client.dart';
import '../engine/location_quality.dart';
import '../engine/osm_place_mapping.dart';

const _overpassUrl = 'https://overpass-api.de/api/interpreter';
// Böyük məkanların (ticarət mərkəzi, hava limanı) OSM node-u GPS mövqeyindən
// xeyli aralı ola bilər — radius geniş tutulur ki, yer tanına bilsin.
const _searchRadiusMeters = 120;
// Qapalı məkanlarda (kafe, market daxili) təzə GPS siqnalı tez-tez 8-10
// saniyəyə tapılmır. GPS-ə bir qədər vaxt veririk, amma əsl sürət qazancı
// timeout olanda son bilinən mövqeyə keçməkdir (aşağıda _getPosition).
const _gpsTimeout = Duration(seconds: 12);
// OSM Overpass sorğusunun öz büdcəsindən ([timeout:5], aşağıda) bir qədər
// böyük saxlanır ki, server cavab verməkdə olanda client vaxtından əvvəl
// kəsməsin.
const _networkTimeout = Duration(seconds: 7);

/// Məkan tapılmadıqda SƏBƏB — UI istifadəçiyə nə edəcəyini deyə bilsin.
/// Əvvəllər hər uğursuzluq eyni `null` idi və istifadəçi problemin GPS-də,
/// icazədə, yoxsa internetdə olduğunu bilmirdi.
enum LocationFailure {
  /// Məkan icazəsi verilməyib.
  permissionDenied,

  /// İcazə "bir daha soruşma" ilə rədd edilib — Ayarlar lazımdır.
  permissionPermanentlyDenied,

  /// Cihazda məkan xidməti söndürülüb.
  serviceDisabled,

  /// GPS vaxtında fix vermədi.
  noFix,

  /// Fix var, amma o qədər qeyri-dəqiqdir ki, yer tanımaq mənasızdır.
  inaccurate,

  /// Koordinat var, amma nə serverdə, nə OSM-də tanınan yer yoxdur.
  noPlaceNearby,

  /// Şəbəkə/server xətası.
  network,
}

/// Məkan həlli nəticəsi — uğur VƏ uğursuzluq halı birlikdə daşınır.
class LocationOutcome {
  const LocationOutcome._({
    this.lat,
    this.lng,
    this.packId,
    this.placeName = '',
    this.category = '',
    this.distanceM,
    this.accuracyM,
    this.quality = FixQuality.approximate,
    this.failure,
    this.fromCache = false,
    this.staleFixAge,
  });

  factory LocationOutcome.success({
    required double lat,
    required double lng,
    String? packId,
    String placeName = '',
    String category = '',
    int? distanceM,
    double? accuracyM,
    FixQuality quality = FixQuality.approximate,
    bool fromCache = false,
    Duration? staleFixAge,
  }) =>
      LocationOutcome._(
        lat: lat,
        lng: lng,
        packId: packId,
        placeName: placeName,
        category: category,
        distanceM: distanceM,
        accuracyM: accuracyM,
        quality: quality,
        fromCache: fromCache,
        staleFixAge: staleFixAge,
      );

  factory LocationOutcome.failed(LocationFailure failure,
          {double? accuracyM}) =>
      LocationOutcome._(failure: failure, accuracyM: accuracyM);

  final double? lat;
  final double? lng;

  /// Null ola bilər: yer tapıldı, amma tipinə uyğun paketimiz yoxdur.
  final String? packId;
  final String placeName;
  final String category;

  /// Yerin koordinatdan metr məsafəsi (server verirsə).
  final int? distanceM;

  /// GPS fix-inin dəqiqlik radiusu (metr).
  final double? accuracyM;
  final FixQuality quality;
  final LocationFailure? failure;
  final bool fromCache;

  /// Son bilinən mövqe işlədilibsə onun yaşı, təzə fix-də null.
  final Duration? staleFixAge;

  bool get isSuccess => failure == null && lat != null;
  bool get hasPack => packId != null && packId!.isNotEmpty;

  /// İstifadəçiyə göstərilən ad.
  String get label => placeName.isNotEmpty ? placeName : category;
}

/// Cihazın GPS-i ilə yaxınlıqdakı yerin tipini müəyyənləşdirir.
///
/// Əsas mənbə: DilDostu serveri (Foursquare) — AZ örtüyü güclü, etibarlı.
/// Server yer tapmasa/əlçatmaz olsa OpenStreetMap Overpass ehtiyat qalır.
///
/// 2026-08-07 dəqiqlik işi:
/// * GPS `LocationAccuracy.high` ilə istənir (əvvəl `medium` ~100-500 m idi,
///   kafeni yanındakı mağazadan ayırmaq mümkün deyildi). Arxa fon toplaması
///   batareya üçün `medium` işlədə bilir (`background: true`).
/// * `Position.accuracy` YOXLANILIR — `maxUsableAccuracyMeters`-dən pis fix
///   rədd edilir (səhv yer deməkdənsə heç nə demə).
/// * Nəticə qısa müddət keşlənir ki, ardıcıl açılışlar eyni yeri göstərsin
///   və Foursquare sorğusu boş yerə təkrarlanmasın.
/// * Uğursuzluq SƏBƏBİ qaytarılır (`LocationFailure`) — UI izah edə bilir.
///
/// Faza 3: `/place/resolve` giriş tələb etdiyi üçün `placeClient` MƏCBURİDİR —
/// çağıran tərəf cari sessiyanın tokeni ilə qurulmuş `PlaceClient` ötürməlidir.
class LocationService {
  LocationService({
    required PlaceClient placeClient,
    http.Client? httpClient,
    DateTime Function()? clock,
  })  : _http = httpClient ?? http.Client(),
        _place = placeClient,
        _now = clock ?? DateTime.now;

  final http.Client _http;
  final PlaceClient _place;
  final DateTime Function() _now;

  _CachedPlace? _cache;

  Future<String?> resolveNearbyPackId() async =>
      (await resolveNearbySample())?.packId;

  /// Rutin toplama üçün: koordinat + paket + yerin adı (köhnə imza qorunur).
  /// Uğursuzluq halında `null` — çağıranlar dəyişmir.
  Future<({double lat, double lng, String packId, String place})?>
      resolveNearbySample({bool background = false}) async {
    final outcome = await resolve(background: background);
    if (!outcome.isSuccess || !outcome.hasPack) return null;
    return (
      lat: outcome.lat!,
      lng: outcome.lng!,
      packId: outcome.packId!,
      place: outcome.label,
    );
  }

  /// Tam nəticə — UI bunu işlədir (səbəb, dəqiqlik, məsafə görünür).
  Future<LocationOutcome> resolve({bool background = false}) async {
    try {
      final permission = await _checkPermission();
      if (permission != null) return LocationOutcome.failed(permission);

      final fix = await _getPosition(background: background);
      if (fix == null) return LocationOutcome.failed(LocationFailure.noFix);

      final quality = classifyFix(fix.position.accuracy);
      if (quality == FixQuality.unusable) {
        return LocationOutcome.failed(
          LocationFailure.inaccurate,
          accuracyM: fix.position.accuracy,
        );
      }

      final lat = fix.position.latitude;
      final lng = fix.position.longitude;

      final cached = _cachedFor(lat, lng);
      if (cached != null) {
        return LocationOutcome.success(
          lat: lat,
          lng: lng,
          packId: cached.packId,
          placeName: cached.placeName,
          category: cached.category,
          distanceM: cached.distanceM,
          accuracyM: fix.position.accuracy,
          quality: quality,
          fromCache: true,
          staleFixAge: fix.age,
        );
      }

      // 1) Əsas: server (Foursquare).
      final server = await _place.resolve(lat, lng);
      if (server != null) {
        _store(lat, lng, server.packId, server.name, server.category,
            server.distanceM);
        return LocationOutcome.success(
          lat: lat,
          lng: lng,
          packId: server.packId,
          placeName: server.name,
          category: server.category,
          distanceM: server.distanceM,
          accuracyM: fix.position.accuracy,
          quality: quality,
          staleFixAge: fix.age,
        );
      }

      // 2) Ehtiyat: OpenStreetMap.
      final tags = await _queryNearbyTags(lat, lng).timeout(_networkTimeout);
      if (tags == null) {
        return LocationOutcome.failed(
          LocationFailure.noPlaceNearby,
          accuracyM: fix.position.accuracy,
        );
      }
      final packId = packIdForOsmTags(tags);
      final name = tags['name'] ?? '';
      _store(lat, lng, packId, name, '', null);
      return LocationOutcome.success(
        lat: lat,
        lng: lng,
        packId: packId,
        placeName: name,
        accuracyM: fix.position.accuracy,
        quality: quality,
        staleFixAge: fix.age,
      );
    } on TimeoutException {
      return LocationOutcome.failed(LocationFailure.network);
    } catch (_) {
      return LocationOutcome.failed(LocationFailure.network);
    }
  }

  _CachedPlace? _cachedFor(double lat, double lng) {
    final cache = _cache;
    if (cache == null) return null;
    final usable = isCacheUsable(
      cachedAt: cache.at,
      cachedLat: cache.lat,
      cachedLng: cache.lng,
      now: _now(),
      currentLat: lat,
      currentLng: lng,
    );
    return usable ? cache : null;
  }

  void _store(double lat, double lng, String? packId, String placeName,
      String category, int? distanceM) {
    _cache = _CachedPlace(
      at: _now(),
      lat: lat,
      lng: lng,
      packId: packId,
      placeName: placeName,
      category: category,
      distanceM: distanceM,
    );
  }

  /// Keşi məcburi təmizləyir — istifadəçi "yenilə"yə basanda təzə sorğu getsin.
  void invalidateCache() => _cache = null;

  /// İcazə/xidmət problemi varsa səbəbi, hər şey qaydasındaysa `null`.
  Future<LocationFailure?> _checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationFailure.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationFailure.permissionPermanentlyDenied;
    }
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return null;
    }
    return LocationFailure.permissionDenied;
  }

  /// Cari mövqeyi tapır: əvvəlcə təzə GPS sorğusu (bağlanmış saytlarda tez-tez
  /// vaxtı keçir), timeout olsa cihazın son bilinən (keşlənmiş) mövqeyinə keçir
  /// ki, qapalı məkanlarda "tapılmadı" halının qarşısı alınsın. Son mövqe
  /// [maxLastKnownAge]-dən köhnədirsə etibarsız sayılır.
  Future<({Position position, Duration? age})?> _getPosition({
    bool background = false,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          // Ön planda `high`: istifadəçi kartda dəqiq yer gözləyir. Arxa fonda
          // `medium`: 20 dəqiqədə bir işlədiyi üçün batareya vacibdir.
          accuracy: background ? LocationAccuracy.medium : LocationAccuracy.high,
          timeLimit: _gpsTimeout,
        ),
      );
      return (position: position, age: null);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;
      final age = _now().difference(last.timestamp);
      if (age > maxLastKnownAge) return null;
      return (position: last, age: age);
    }
  }

  /// "İndi yoxla" diaqnostikası — hər mərhələni insanoxunaqlı sətir kimi qaytarır
  /// (koordinat, dəqiqlik, server nəticəsi, OSM ehtiyatı) ki, problem harada
  /// olduğu görünsün.
  Future<String> diagnose() async {
    try {
      final permission = await _checkPermission();
      if (permission != null) return describeFailure(permission);

      final fix = await _getPosition();
      if (fix == null) {
        return 'GPS siqnalı ${_gpsTimeout.inSeconds}s ərzində tapılmadı və '
            'cihazda istifadəyə yararlı son mövqe yoxdur. Açıq havada '
            'yenidən yoxla.';
      }
      final position = fix.position;
      final quality = classifyFix(position.accuracy);
      final coord =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      final source = fix.age == null
          ? ' (təzə GPS)'
          : ' (son bilinən, ${fix.age!.inMinutes} dəq əvvəl)';
      final accuracy = '±${position.accuracy.round()} m '
          '(${_qualityLabel(quality)})';

      if (quality == FixQuality.unusable) {
        return 'Məkan: $coord$source\nDəqiqlik: $accuracy\n'
            'Bu dəqiqliklə yer tanımaq mümkün deyil — açıq havada və ya '
            'Wi-Fi açıq halda yenidən yoxla.';
      }

      final server = await _place.resolve(position.latitude, position.longitude);
      if (server != null) {
        final distance =
            server.distanceM != null ? ', ${server.distanceM} m' : '';
        return 'Məkan: $coord$source\nDəqiqlik: $accuracy\n'
            'Tapıldı (server): ${server.label}$distance\n'
            'Kateqoriya: ${server.category} → paket: '
            '${server.packId ?? "bu tip paketimizdə yoxdur"}';
      }

      // Server nəticə vermədi — OSM ehtiyatını yoxla.
      final tags = await _queryNearbyTags(position.latitude, position.longitude)
          .timeout(_networkTimeout);
      if (tags == null) {
        return 'Məkan: $coord$source\nDəqiqlik: $accuracy\n'
            'Nə serverdə, nə OSM-də ${_searchRadiusMeters}m radiusda qeydiyyatlı '
            'yer tapılmadı (yəqin evdəsən). Kafe/market kimi yerdə yenidən yoxla.';
      }
      final tagStr =
          tags.entries.take(3).map((e) => '${e.key}=${e.value}').join(', ');
      final packId = packIdForOsmTags(tags);
      return 'Məkan: $coord$source\nDəqiqlik: $accuracy\nOSM tapdı: $tagStr\n'
          'Paket: ${packId ?? "bu tip paketimizdə yoxdur"}';
    } catch (e) {
      return 'Məkan alınmadı (GPS/internet xətası). Yenidən cəhd et.';
    }
  }

  String _qualityLabel(FixQuality quality) => switch (quality) {
        FixQuality.precise => 'dəqiq',
        FixQuality.approximate => 'təxmini',
        FixQuality.unusable => 'çox qeyri-dəqiq',
      };

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

/// Uğursuzluğun istifadəçiyə göstərilən izahı — hər səbəb üçün NƏ EDƏCƏYİ də
/// deyilir (yalnız "alınmadı" demək istifadəçiyə kömək etmir).
String describeFailure(LocationFailure failure) => switch (failure) {
      LocationFailure.permissionDenied =>
        'Məkan icazəsi verilməyib — icazə versən olduğun yerə uyğun sözlər '
            'göstərəcəyəm.',
      LocationFailure.permissionPermanentlyDenied =>
        'Məkan icazəsi bağlanıb. Ayarlar → İcazələr → Məkan bölməsindən aç.',
      LocationFailure.serviceDisabled =>
        'Cihazda məkan xidməti söndürülüb — onu açıb yenidən yoxla.',
      LocationFailure.noFix =>
        'GPS siqnalı tapılmadı. Qapalı məkanda siqnal zəif olur — pəncərə '
            'yanında və ya çöldə yenidən yoxla.',
      LocationFailure.inaccurate =>
        'GPS siqnalı çox qeyri-dəqiqdir, səhv yer göstərmək istəmirəm. '
            'Wi-Fi-ı açsan dəqiqlik artır.',
      LocationFailure.noPlaceNearby =>
        'Yaxınlıqda qeydiyyatlı yer tapılmadı — yəqin evdəsən. Aşağıdan özün '
            'seçə bilərsən.',
      LocationFailure.network =>
        'İnternet bağlantısı yoxdur — yeri müəyyən edə bilmirəm.',
    };

class _CachedPlace {
  const _CachedPlace({
    required this.at,
    required this.lat,
    required this.lng,
    required this.packId,
    required this.placeName,
    required this.category,
    required this.distanceM,
  });

  final DateTime at;
  final double lat;
  final double lng;
  final String? packId;
  final String placeName;
  final String category;
  final int? distanceM;
}
