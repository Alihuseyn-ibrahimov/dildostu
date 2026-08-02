import 'package:dildostu/src/data/settings_repository.dart';
import 'package:dildostu/src/models/settings.dart';
import 'package:dildostu/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('defolt dəyərləri göstərir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(repository: repo)));

    expect(find.text('${Settings.defaults.wakeHour}:00'), findsOneWidget);
    expect(find.text('${Settings.defaults.dailyNotificationCount}'), findsOneWidget);
  });

  testWidgets('bildiriş sayını artırmaq üçün + düyməsi işləyir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(repository: repo)));

    final startCount = repo.current.dailyNotificationCount;
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(repo.current.dailyNotificationCount, startCount + 1);
    expect(find.text('${startCount + 1}'), findsOneWidget);
  });

  testWidgets('10-dan yuxarı artırılmır (maksimum)', (tester) async {
    final repo = await SettingsRepository.load();
    await repo.save(const Settings(
      wakeHour: 8, wakeMinute: 0, sleepHour: 22, sleepMinute: 0,
      dailyNotificationCount: 10,
    ));
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(repository: repo)));

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(repo.current.dailyNotificationCount, 10);
  });

  testWidgets('buildLabel verilibsə Buraxılış sətri göstərir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(repository: repo, buildLabel: '1.0.0+7'),
    ));

    expect(find.text('1.0.0+7'), findsOneWidget);
  });

  testWidgets('buildLabel yoxdursa Buraxılış sətri göstərilmir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(repository: repo)));

    expect(find.text('Buraxılış'), findsNothing);
  });
}
