import 'dart:math';

import '../models/geofence_zone.dart';

const _earthRadiusM = 6371000.0;
const _defaultCooldown = Duration(hours: 2);

double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  final phi1 = lat1 * pi / 180;
  final phi2 = lat2 * pi / 180;
  final dPhi = (lat2 - lat1) * pi / 180;
  final dLambda = (lng2 - lng1) * pi / 180;
  final a = sin(dPhi / 2) * sin(dPhi / 2) +
      cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
  return 2 * _earthRadiusM * asin(sqrt(a));
}

/// Cari koordinat zonalardan hansının daxilindədir (varsa) — ən yaxını qaytarır.
/// Heç biri uyğun gəlmirsə `null` (WorkManager tick-i bildiriş göndərmir).
GeofenceZone? findArrivalZone({
  required double lat,
  required double lng,
  required List<GeofenceZone> zones,
}) {
  GeofenceZone? closest;
  double closestDistance = double.infinity;
  for (final zone in zones) {
    final distance = _haversineMeters(lat, lng, zone.centerLat, zone.centerLng);
    if (distance <= zone.radius && distance < closestDistance) {
      closest = zone;
      closestDistance = distance;
    }
  }
  return closest;
}

/// İstifadəçi hələ də eyni yerdə olarkən hər 20 dəqiqədə bir bildiriş
/// göndərməmək üçün kooldown yoxlaması. Defolt 2 saat.
bool shouldNotifyArrival({
  required DateTime? lastNotifiedAt,
  required DateTime now,
  Duration cooldown = _defaultCooldown,
}) {
  if (lastNotifiedAt == null) return true;
  return now.difference(lastNotifiedAt) >= cooldown;
}

typedef FetchGeofences = Future<List<GeofenceZone>> Function();
typedef GetLastNotified = DateTime? Function(String zoneKey);
typedef MarkNotified = Future<void> Function(String zoneKey, DateTime at);
typedef NotifyArrival = Future<void> Function(String packId, String label);

/// WorkManager periodik tick-inin geofence yoxlaması: serverdən zonaları
/// gətirir, cari mövqe daxilindəkini tapır, kooldown keçibsə bildiriş göndərir.
/// Plugin-siz, təmiz orkestrasiya — effektlər (şəbəkə, saxlama, bildiriş)
/// inject olunur → mock-larla test oluna bilir.
Future<void> checkGeofenceArrival({
  required double lat,
  required double lng,
  required FetchGeofences fetchGeofences,
  required GetLastNotified getLastNotified,
  required MarkNotified markNotified,
  required NotifyArrival notify,
  DateTime? now,
}) async {
  final zones = await fetchGeofences();
  if (zones.isEmpty) return;

  final zone = findArrivalZone(lat: lat, lng: lng, zones: zones);
  if (zone == null) return;

  final effectiveNow = now ?? DateTime.now();
  if (!shouldNotifyArrival(
      lastNotifiedAt: getLastNotified(zone.stableKey), now: effectiveNow)) {
    return;
  }

  await notify(zone.packId, zone.label);
  await markNotified(zone.stableKey, effectiveNow);
}
