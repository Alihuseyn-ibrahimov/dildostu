import 'package:dildostu/src/engine/location_quality.dart';
import 'package:dildostu/src/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocationOutcome', () {
    test('uğurlu nəticə koordinat və paket daşıyır', () {
      final outcome = LocationOutcome.success(
        lat: 40.37,
        lng: 49.83,
        packId: 'cafe',
        placeName: 'Kofe Evi',
        distanceM: 27,
        accuracyM: 12,
        quality: FixQuality.precise,
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.hasPack, isTrue);
      expect(outcome.label, 'Kofe Evi');
      expect(outcome.failure, isNull);
    });

    test('paketsiz yer uğurludur, amma hasPack yalandır', () {
      final outcome = LocationOutcome.success(
        lat: 40.37,
        lng: 49.83,
        placeName: 'Dənizkənarı Park',
      );

      expect(outcome.isSuccess, isTrue);
      expect(outcome.hasPack, isFalse);
    });

    test('ad yoxdursa label kateqoriyaya düşür', () {
      final outcome = LocationOutcome.success(
        lat: 0,
        lng: 0,
        category: 'Coffee Shop',
      );
      expect(outcome.label, 'Coffee Shop');
    });

    test('uğursuz nəticədə koordinat yoxdur, səbəb var', () {
      final outcome = LocationOutcome.failed(LocationFailure.inaccurate,
          accuracyM: 1800);

      expect(outcome.isSuccess, isFalse);
      expect(outcome.failure, LocationFailure.inaccurate);
      expect(outcome.accuracyM, 1800);
      expect(outcome.lat, isNull);
    });
  });

  group('describeFailure', () {
    test('hər səbəb üçün boş olmayan Azərbaycanca izah var', () {
      for (final failure in LocationFailure.values) {
        final text = describeFailure(failure);
        expect(text, isNotEmpty, reason: '${failure.name} izahsız qalıb');
        expect(text.length, greaterThan(20),
            reason: '${failure.name} izahı çox qısadır');
      }
    });

    test('icazə bağlıdırsa Ayarlara yönləndirir', () {
      expect(describeFailure(LocationFailure.permissionPermanentlyDenied),
          contains('Ayarlar'));
    });

    test('məkan xidməti söndürülübsə onu açmağı deyir', () {
      expect(describeFailure(LocationFailure.serviceDisabled),
          contains('söndürülüb'));
    });

    test('qeyri-dəqiq fix üçün Wi-Fi məsləhəti verilir', () {
      expect(describeFailure(LocationFailure.inaccurate), contains('Wi-Fi'));
    });

    test('yaxınlıqda yer yoxdursa özün seç deyir', () {
      expect(describeFailure(LocationFailure.noPlaceNearby), contains('seçə'));
    });
  });
}
