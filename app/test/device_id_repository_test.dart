import 'package:dildostu/src/data/device_id_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ilk açılışda id yaradır və saxlayır', () async {
    final repo = await DeviceIdRepository.load();
    expect(repo.deviceId, isNotEmpty);
    expect(repo.deviceId.length, greaterThanOrEqualTo(16));
  });

  test('ikinci yükləmə eyni id qaytarır (davamlı)', () async {
    final first = (await DeviceIdRepository.load()).deviceId;
    final second = (await DeviceIdRepository.load()).deviceId;
    expect(second, first);
  });

  test('fərqli id-lər təsadüfidir', () async {
    final a = (await DeviceIdRepository.load()).deviceId;
    SharedPreferences.setMockInitialValues({});
    final b = (await DeviceIdRepository.load()).deviceId;
    expect(a, isNot(b));
  });
}
