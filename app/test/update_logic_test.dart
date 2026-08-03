import 'package:dildostu/src/engine/update_logic.dart';
import 'package:dildostu/src/models/app_version_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('checkForUpdate', () {
    test('server versiyası yoxdursa (404/xəta) yeniləmə yoxdur', () async {
      final result = await checkForUpdate(
        currentVersionCode: 3,
        fetchVersion: () async => null,
      );
      expect(result, isNull);
    });

    test('server versiyası eyni və ya köhnədirsə yeniləmə yoxdur', () async {
      expect(
        await checkForUpdate(
          currentVersionCode: 5,
          fetchVersion: () async => const AppVersionInfo(
              versionCode: 5, versionName: '1.0.0+5', notes: ''),
        ),
        isNull,
      );
      expect(
        await checkForUpdate(
          currentVersionCode: 5,
          fetchVersion: () async => const AppVersionInfo(
              versionCode: 4, versionName: '1.0.0+4', notes: ''),
        ),
        isNull,
      );
    });

    test('server versiyası yenidirsə DƏRHAL (yükləmədən) məlumat qaytarır',
        () async {
      // Vacib: yükləmə burada BAŞLAMIR — zolaq dərhal görünsün deyə.
      // Əvvəl 150+ MB tam yüklənənə qədər null qaytarılırdı və zolaq
      // praktikada heç vaxt çıxmırdı.
      final result = await checkForUpdate(
        currentVersionCode: 3,
        fetchVersion: () async => const AppVersionInfo(
            versionCode: 5, versionName: '1.0.0+5', notes: 'düzəliş'),
      );
      expect(result, isNotNull);
      expect(result!.versionCode, 5);
      expect(result.versionName, '1.0.0+5');
      expect(result.notes, 'düzəliş');
    });
  });
}
