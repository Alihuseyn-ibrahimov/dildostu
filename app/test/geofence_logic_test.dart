import 'package:dildostu/src/engine/geofence_logic.dart';
import 'package:dildostu/src/models/geofence_zone.dart';
import 'package:flutter_test/flutter_test.dart';

GeofenceZone _zone({
  double lat = 40.370,
  double lng = 49.830,
  double radius = 100,
  String packId = 'cafe',
}) =>
    GeofenceZone(
        centerLat: lat, centerLng: lng, radius: radius, packId: packId, label: packId);

void main() {
  group('findArrivalZone', () {
    test('daxildÉ™ki nÃ¶qtÉ™ Ã¼Ã§Ã¼n zona tapÄ±r', () {
      final zones = [_zone()];
      final result =
          findArrivalZone(lat: 40.3701, lng: 49.8300, zones: zones);
      expect(result, isNotNull);
      expect(result!.packId, 'cafe');
    });

    test('radiusdan kÉ™nar nÃ¶qtÉ™ Ã¼Ã§Ã¼n null', () {
      final zones = [_zone(radius: 50)];
      // ~200m aralÄ±
      final result = findArrivalZone(lat: 40.372, lng: 49.830, zones: zones);
      expect(result, isNull);
    });

    test('boÅŸ siyahÄ± Ã¼Ã§Ã¼n null', () {
      expect(findArrivalZone(lat: 40.37, lng: 49.83, zones: const []), isNull);
    });

    test('É™n yaxÄ±n zonanÄ± seÃ§ir (bir neÃ§É™ uyÄŸun olsa)', () {
      final zones = [
        _zone(lat: 40.3700, lng: 49.8300, radius: 300, packId: 'far'),
        _zone(lat: 40.37001, lng: 49.83001, radius: 300, packId: 'near'),
      ];
      final result =
          findArrivalZone(lat: 40.37001, lng: 49.83001, zones: zones);
      expect(result!.packId, 'near');
    });
  });

  group('shouldNotifyArrival', () {
    test('É™vvÉ™llÉ™r bildirilmÉ™yibsÉ™ true', () {
      expect(
        shouldNotifyArrival(
            lastNotifiedAt: null, now: DateTime(2026, 8, 2, 10, 0)),
        isTrue,
      );
    });

    test('kooldown daxilindÉ™dirsÉ™ false', () {
      final last = DateTime(2026, 8, 2, 10, 0);
      final now = last.add(const Duration(minutes: 30));
      expect(
        shouldNotifyArrival(lastNotifiedAt: last, now: now),
        isFalse,
      );
    });

    test('kooldowndan sonra yenidÉ™n true', () {
      final last = DateTime(2026, 8, 2, 10, 0);
      final now = last.add(const Duration(hours: 3));
      expect(
        shouldNotifyArrival(lastNotifiedAt: last, now: now),
        isTrue,
      );
    });

    test('xÃ¼susi kooldown mÃ¼ddÉ™ti', () {
      final last = DateTime(2026, 8, 2, 10, 0);
      final now = last.add(const Duration(minutes: 45));
      expect(
        shouldNotifyArrival(
            lastNotifiedAt: last,
            now: now,
            cooldown: const Duration(minutes: 30)),
        isTrue,
      );
    });
  });

  group('checkGeofenceArrival', () {
    test('zona daxilindÉ™dirsÉ™ vÉ™ kooldown keÃ§ibsÉ™ bildirir', () async {
      String? notifiedPack;
      String? markedKey;
      DateTime? markedAt;
      await checkGeofenceArrival(
        lat: 40.3701,
        lng: 49.8300,
        fetchGeofences: () async => [_zone()],
        getLastNotified: (_) => null,
        markNotified: (key, at) async {
          markedKey = key;
          markedAt = at;
        },
        notify: (packId, label) async => notifiedPack = packId,
        now: DateTime(2026, 8, 2, 10, 0),
      );
      expect(notifiedPack, 'cafe');
      expect(markedKey, isNotNull);
      expect(markedAt, DateTime(2026, 8, 2, 10, 0));
    });

    test('zona yoxdursa bildirmir', () async {
      var notified = false;
      await checkGeofenceArrival(
        lat: 40.37,
        lng: 49.83,
        fetchGeofences: () async => const [],
        getLastNotified: (_) => null,
        markNotified: (_, _) async {},
        notify: (_, _) async => notified = true,
      );
      expect(notified, isFalse);
    });

    test('radiusdan kÉ™nardadÄ±rsa bildirmir', () async {
      var notified = false;
      await checkGeofenceArrival(
        lat: 40.5,
        lng: 50.0,
        fetchGeofences: () async => [_zone()],
        getLastNotified: (_) => null,
        markNotified: (_, _) async {},
        notify: (_, _) async => notified = true,
      );
      expect(notified, isFalse);
    });

    test('kooldown daxilindÉ™dirsÉ™ bildirmir', () async {
      var notified = false;
      final now = DateTime(2026, 8, 2, 10, 0);
      await checkGeofenceArrival(
        lat: 40.3701,
        lng: 49.8300,
        fetchGeofences: () async => [_zone()],
        getLastNotified: (_) => now.subtract(const Duration(minutes: 30)),
        markNotified: (_, _) async {},
        notify: (_, _) async => notified = true,
        now: now,
      );
      expect(notified, isFalse);
    });
  });
}
