import 'package:dildostu/src/data/settings_repository.dart';
import 'package:dildostu/src/models/settings.dart';
import 'package:dildostu/src/models/ui_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('heç nə saxlanmayıbsa defolt qaytarır', () async {
    final repo = await SettingsRepository.load();
    expect(repo.current.wakeHour, Settings.defaults.wakeHour);
    expect(repo.current.dailyNotificationCount, Settings.defaults.dailyNotificationCount);
  });

  test('save sonra yeni instansiya dəyəri geri oxuyur', () async {
    final repo = await SettingsRepository.load();
    const updated = Settings(
      wakeHour: 7,
      wakeMinute: 15,
      sleepHour: 23,
      sleepMinute: 30,
      dailyNotificationCount: 9,
    );
    await repo.save(updated);

    final reloaded = await SettingsRepository.load();
    expect(reloaded.current.wakeHour, 7);
    expect(reloaded.current.wakeMinute, 15);
    expect(reloaded.current.dailyNotificationCount, 9);
  });

  test('uiLanguage saxlanır və geri oxunur', () async {
    final repo = await SettingsRepository.load();
    await repo.save(Settings.defaults.copyWith(uiLanguage: UiLanguage.en));
    final reloaded = await SettingsRepository.load();
    expect(reloaded.current.uiLanguage, UiLanguage.en);
  });
}
