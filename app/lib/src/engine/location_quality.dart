/// GPS fix-inin keyfiyyət qiymətləndirməsi və məkan keşi qaydaları.
///
/// Təmiz funksiyalar — `geolocator` plugin-indən asılı deyil, ona görə unit
/// test olunur (`LocationService`-in özü plugin asılılığına görə test edilmir).
library;

import 'dart:math' as math;

/// Bu həddən pis fix POI uyğunlaşdırması üçün mənasızdır: server 200 m
/// radiusda axtarır, ±500 m səhvlə "yaxınlıqdaki yer" təsadüfi olur.
/// Belə fix-lər rədd edilir — səhv cavab verməkdənsə heç nə deməmək yaxşıdır.
const maxUsableAccuracyMeters = 500.0;

/// Bu həddən yaxşı fix "dəqiq" sayılır; arasındakılar istifadə olunur, amma
/// UI-da "təxmini" kimi işarələnir (istifadəçi nəyə güvəndiyini bilsin).
const goodAccuracyMeters = 100.0;

/// Keşlənmiş məkan bu müddətdən köhnə olarsa yenidən sorğu edilir.
const placeCacheTtl = Duration(minutes: 5);

/// İstifadəçi bu məsafədən çox hərəkət edibsə keş etibarsızdır.
const placeCacheRadiusMeters = 60.0;

/// Son bilinən (keşlənmiş) mövqe bu müddətdən köhnədirsə istifadə edilmir.
/// Əvvəl 10 dəqiqə idi — maşınla 10 dəqiqədə bir neçə kilometr getmək olur,
/// ona görə qısaldılıb.
const maxLastKnownAge = Duration(minutes: 5);

/// GPS fix-inin nə dərəcədə etibarlı olduğu.
enum FixQuality {
  /// Yer tanımaq üçün yetərincə dəqiq.
  precise,

  /// İstifadə olunur, amma UI "təxmini" deməlidir.
  approximate,

  /// Çox pis — istifadə edilmir.
  unusable,
}

/// `accuracy` metr radiusudur (geolocator `Position.accuracy`).
/// Mənfi/sıfır dəyər bəzi cihazlarda "bilinmir" deməkdir — təxmini sayılır.
FixQuality classifyFix(double accuracyMeters) {
  if (accuracyMeters <= 0) return FixQuality.approximate;
  if (accuracyMeters <= goodAccuracyMeters) return FixQuality.precise;
  if (accuracyMeters <= maxUsableAccuracyMeters) return FixQuality.approximate;
  return FixQuality.unusable;
}

/// İki koordinat arası məsafə (metr) — haversine.
double distanceMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadius = 6371000.0;
  double toRad(double d) => d * math.pi / 180.0;
  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(a.toDouble()));
}

/// Keşlənmiş nəticə hələ etibarlıdırmı: kifayət qədər təzə VƏ istifadəçi
/// əhəmiyyətli məsafə qət etməmiş.
///
/// Bu, "iki dəfə açanda fərqli yer göstərir" problemini həll edir və
/// Foursquare sorğularını azaldır.
bool isCacheUsable({
  required DateTime cachedAt,
  required double cachedLat,
  required double cachedLng,
  required DateTime now,
  required double currentLat,
  required double currentLng,
}) {
  if (now.difference(cachedAt) > placeCacheTtl) return false;
  final moved =
      distanceMeters(cachedLat, cachedLng, currentLat, currentLng);
  return moved <= placeCacheRadiusMeters;
}

/// Serverin verdiyi məsafəyə görə yerin "buradasan" iddiasının gücü.
/// Uzaq yer üçün UI "yaxınlıqda" deyir, yaxın üçün "buradasan".
bool isAtPlace(int? distanceMeters) =>
    distanceMeters != null && distanceMeters <= 60;
