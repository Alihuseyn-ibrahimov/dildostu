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

  _diagnosticsTests();

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

  testWidgets('onOpenPrivacyPolicy verilibsə keçid göstərir və toxunanda çağırır',
      (tester) async {
    var called = false;
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        repository: repo,
        onOpenPrivacyPolicy: () => called = true,
      ),
    ));

    expect(find.text('Məxfilik siyasəti'), findsOneWidget);
    await tester.tap(find.text('Məxfilik siyasəti'));
    expect(called, isTrue);
  });

  testWidgets('onOpenPrivacyPolicy verilməyibsə göstərilmir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(repository: repo)));

    expect(find.text('Məxfilik siyasəti'), findsNothing);
  });
}

// --- Yeniləmə diaqnostikası (Ayarlar) ---
// Yeniləmə mexanizmi bir neçə səssiz yolla sına bilirdi; bu bölmə nəticəni
// açıq göstərir ki, səbəb bir toxunuşla görünsün.
void _diagnosticsTests() {
  testWidgets('onCheckUpdate yoxdursa bölmə göstərilmir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(repository: repo)));
    expect(find.text('Yeniləməni yoxla'), findsNothing);
  });

  testWidgets('toxunanda nəticə mətni göstərilir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        repository: repo,
        onCheckUpdate: () async => 'Sən: 1.0.0+20\n✅ Ən son versiyadasan.',
      ),
    ));
    await tester.tap(find.text('Yeniləməni yoxla'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ən son versiyadasan'), findsOneWidget);
  });

  testWidgets('yoxlama istisna atsa da səbəb göstərilir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        repository: repo,
        onCheckUpdate: () async => throw Exception('SocketException'),
      ),
    ));
    await tester.tap(find.text('Yeniləməni yoxla'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SocketException'), findsOneWidget);
  });
}
