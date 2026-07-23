import 'package:dildostu/src/engine/update_logic.dart';
import 'package:dildostu/src/models/app_version_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('checkForUpdate', () {
    test('server versiyası yoxdursa (404/xəta) yeniləmə yoxdur', () async {
      final result = await checkForUpdate(
        currentVersionCode: 3,
        fetchVersion: () async => null,
        downloadApk: () async => '/tmp/x.apk',
      );
      expect(result, isNull);
    });

    test('server versiyası eyni və ya köhnədirsə yeniləmə yoxdur', () async {
      var downloadCalled = false;
      final result = await checkForUpdate(
        currentVersionCode: 5,
        fetchVersion: () async => const AppVersionInfo(
            versionCode: 5, versionName: '1.0.0+5', notes: ''),
        downloadApk: () async {
          downloadCalled = true;
          return '/tmp/x.apk';
        },
      );
      expect(result, isNull);
      expect(downloadCalled, isFalse); // köhnədirsə yükləməyə ehtiyac yoxdur
    });

    test('server versiyası yenidirsə yükləyir və nəticə qaytarır', () async {
      String? downloadedTo;
      final result = await checkForUpdate(
        currentVersionCode: 3,
        fetchVersion: () async => const AppVersionInfo(
            versionCode: 5, versionName: '1.0.0+5', notes: 'düzəliş'),
        downloadApk: () async {
          downloadedTo = '/tmp/dildostu-update.apk';
          return downloadedTo!;
        },
      );
      expect(result, isNotNull);
      expect(result!.versionInfo.versionCode, 5);
      expect(result.apkPath, '/tmp/dildostu-update.apk');
      expect(downloadedTo, isNotNull);
    });

    test('yükləmə uğursuzsa (null) banner göstərilmir', () async {
      final result = await checkForUpdate(
        currentVersionCode: 3,
        fetchVersion: () async => const AppVersionInfo(
            versionCode: 5, versionName: '1.0.0+5'),
        downloadApk: () async => null,
      );
      expect(result, isNull);
    });
  });
}
