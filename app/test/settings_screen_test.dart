import 'dart:async';

import 'package:dildostu/src/data/settings_repository.dart';
import 'package:dildostu/src/models/ui_language.dart';
import 'package:dildostu/src/data/tts_telemetry_repository.dart';
import 'package:dildostu/src/models/app_version_info.dart';
import 'package:dildostu/src/models/chat_quota.dart';
import 'package:dildostu/src/models/settings.dart';
import 'package:dildostu/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_test_harness.dart';

const _info = AppVersionInfo(versionCode: 20, versionName: '1.0.0+20');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  _updateFlowTests();

  testWidgets('defolt dəyərləri göstərir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo)));

    expect(find.text('${Settings.defaults.wakeHour}:00'), findsOneWidget);
    expect(find.text('${Settings.defaults.dailyNotificationCount}'), findsOneWidget);
  });

  testWidgets('bildiriş sayını artırmaq üçün + düyməsi işləyir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo)));

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
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo)));

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(repo.current.dailyNotificationCount, 10);
  });

  testWidgets('buildLabel verilibsə Buraxılış sətri göstərir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo, buildLabel: '1.0.0+7'),
    ));

    expect(find.text('1.0.0+7'), findsOneWidget);
  });

  testWidgets('buildLabel yoxdursa Buraxılış sətri göstərilmir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo)));

    expect(find.text('Buraxılış'), findsNothing);
  });

  testWidgets('onOpenPrivacyPolicy verilibsə keçid göstərir və toxunanda çağırır',
      (tester) async {
    var called = false;
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
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
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo)));

    expect(find.text('Məxfilik siyasəti'), findsNothing);
  });

  testWidgets('ttsTelemetry verilməyibsə "Səs statistikası" göstərilmir',
      (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo)));

    expect(find.text('Səs statistikası (daxili)'), findsNothing);
  });

  testWidgets('öyrənilən dil seçicisi Ayarlarda YOXDUR (ana səhifədədir)',
      (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo)));

    expect(find.text('Öyrənilən dil'), findsNothing);
    expect(find.text('İspan'), findsNothing);
  });

  testWidgets('proqram dili seçicisi Ayarlarda göstərilir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo)));

    expect(find.text('Proqram dili'), findsOneWidget);
    expect(find.text('Azərbaycan dili'), findsOneWidget);
  });

  testWidgets('proqram dili dəyişəndə callback çağırılır', (tester) async {
    UiLanguage? picked;
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
      repository: repo,
      onUiLanguageChanged: (lang) => picked = lang,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Azərbaycan dili'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(picked, UiLanguage.en);
    expect(repo.current.uiLanguage, UiLanguage.en);
  });

  testWidgets('ttsTelemetry verilibsə uğursuzluq faizini göstərir',
      (tester) async {
    final repo = await SettingsRepository.load();
    final telemetry = TtsTelemetry(
      attempts: 10,
      failures: 3,
      noVoiceDetections: 1,
      since: DateTime.now().subtract(const Duration(days: 4)),
    );
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo, ttsTelemetry: telemetry),
    ));

    expect(find.text('Səs statistikası (daxili)'), findsOneWidget);
    expect(find.textContaining('10 cəhd'), findsOneWidget);
    expect(find.textContaining('3 uğursuz'), findsOneWidget);
    expect(find.textContaining('30.0%'), findsOneWidget);
  });

  _chatMemoryTests();
}

// --- AI yaddaşı (2026-08-06) ---
//
// İstifadəçi AI-nin onun haqqında nə bildiyini görməli və silə bilməlidir.
// Tarixçə və portret AYRI silinir — testlər bu ayrımı qoruyur.
void _chatMemoryTests() {
  Future<void> pump(
    WidgetTester tester, {
    required List<String> facts,
    Future<ChatQuota?> Function()? loadChatQuota,
    Future<bool> Function()? onClearHistory,
    Future<bool> Function()? onClearPortrait,
  }) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
        repository: repo,
        loadChatPortrait: () async => facts,
        loadChatQuota: loadChatQuota,
        onClearChatHistory: onClearHistory,
        onClearChatPortrait: onClearPortrait,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loadChatPortrait verilməyibsə bölmə göstərilmir',
      (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(repository: repo)));
    expect(find.text('AI yaddaşı'), findsNothing);
  });

  testWidgets('faktlar çip kimi göstərilir və sayılır', (tester) async {
    await pump(tester, facts: ['Ad: Elvin', 'Hobbi: foto']);

    expect(find.text('AI yaddaşı'), findsOneWidget);
    expect(find.textContaining('2 şey bilir'), findsOneWidget);
    expect(find.text('Ad: Elvin'), findsOneWidget);
    expect(find.text('Hobbi: foto'), findsOneWidget);
  });

  testWidgets('fakt yoxdursa izahlı mesaj göstərilir', (tester) async {
    await pump(tester, facts: const []);
    expect(find.textContaining('hələ sənin haqqında heç nə'), findsOneWidget);
  });

  testWidgets('loadChatQuota veriləndə kvota sətri göstərilir', (tester) async {
    await pump(
      tester,
      facts: const [],
      loadChatQuota: () async =>
          const ChatQuota(used: 3, limit: 80, remaining: 77),
    );
    expect(find.text('Gündəlik söhbət limiti'), findsOneWidget);
    expect(find.textContaining('3/80'), findsOneWidget);
    expect(find.textContaining('Qalıb 77'), findsOneWidget);
  });

  testWidgets('söhbəti təmizlə — təsdiqdən sonra çağırılır', (tester) async {
    var called = false;
    await pump(
      tester,
      facts: const ['Ad: Elvin'],
      onClearHistory: () async {
        called = true;
        return true;
      },
    );

    await tester.tap(find.text('Söhbəti təmizlə'));
    await tester.pumpAndSettle();
    expect(called, isFalse, reason: 'təsdiq olmadan silinməməlidir');

    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(find.text('Söhbət təmizləndi'), findsOneWidget);
  });

  testWidgets('imtina ediləndə heç nə silinmir', (tester) async {
    var called = false;
    await pump(
      tester,
      facts: const ['Ad: Elvin'],
      onClearPortrait: () async {
        called = true;
        return true;
      },
    );

    await tester.tap(find.text('AI yaddaşını sıfırla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İmtina'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('silmə uğursuz olsa səbəb göstərilir (səssiz udulmur)',
      (tester) async {
    await pump(
      tester,
      facts: const ['Ad: Elvin'],
      onClearPortrait: () async => false,
    );

    await tester.tap(find.text('AI yaddaşını sıfırla'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Alınmadı'), findsOneWidget);
  });
}

// --- Yeniləmə axını (Ayarlar) ---
//
// Bu axın QƏSDƏN Ana səhifədə DEYİL, burada yaşayır: "Yenilə" zolağının Ana
// səhifədə dinamik göstərilməsi Samsung S926B-də tabı əbədi boş qoyurdu
// (bax home_tab.dart-dakı izah). Ayarlar öz ayrı marşrutu olduğu üçün bu
// problem sinfini kökündən aradan qaldırır.
void _updateFlowTests() {
  testWidgets('fetchUpdate yoxdursa bölmə göstərilmir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(
        wrapWithLocale(SettingsScreen(repository: repo)));
    expect(find.text('Yeniləmələr'), findsNothing);
  });

  testWidgets('açılışda avtomatik yoxlayır, yenisi yoxdursa "Ən son versiyadasan"',
      (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
        repository: repo,
        fetchUpdate: () async => (info: null, error: null),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ən son versiyadasan'), findsOneWidget);
  });

  testWidgets('yeni versiya varsa banner göstərilir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
        repository: repo,
        fetchUpdate: () async => (info: _info, error: null),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.0.0+20'), findsOneWidget);
    expect(find.text('Yenilə'), findsOneWidget);
  });

  testWidgets('yoxlama xətası səbəblə göstərilir (səssiz uğursuzluq yox)',
      (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
        repository: repo,
        fetchUpdate: () async => (info: null, error: 'server 403 qaytardı'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('403'), findsOneWidget);
  });

  testWidgets('yoxlama istisna atsa da səbəb göstərilir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
        repository: repo,
        fetchUpdate: () async => throw Exception('SocketException'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('SocketException'), findsOneWidget);
  });

  testWidgets('yenidən yoxla düyməsi təkrar çağırır', (tester) async {
    var calls = 0;
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
        repository: repo,
        fetchUpdate: () async {
          calls++;
          return (info: null, error: null);
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('"Yenilə" toxunuşu yükləməni başladır və faiz göstərir',
      (tester) async {
    final completer = Completer<String?>();
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
        repository: repo,
        fetchUpdate: () async => (info: _info, error: null),
        downloadUpdate: (onProgress) {
          onProgress(50, 100);
          return completer.future;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yenilə'));
    await tester.pump();
    expect(find.textContaining('Yüklənir'), findsOneWidget);
    completer.complete('/tmp/x.apk');
    await tester.pumpAndSettle();
  });

  testWidgets('yükləmə uğurlu olanda quraşdırma çağırılır', (tester) async {
    String? installed;
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
        repository: repo,
        fetchUpdate: () async => (info: _info, error: null),
        downloadUpdate: (onProgress) async => '/tmp/x.apk',
        onInstallApk: (path) async => installed = path,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yenilə'));
    await tester.pumpAndSettle();
    expect(installed, '/tmp/x.apk');
  });

  testWidgets('yükləmə uğursuzsa "Yenidən cəhd et" göstərilir', (tester) async {
    final repo = await SettingsRepository.load();
    await tester.pumpWidget(wrapWithLocale(SettingsScreen(
        repository: repo,
        fetchUpdate: () async => (info: _info, error: null),
        downloadUpdate: (onProgress) async => null,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yenilə'));
    await tester.pumpAndSettle();
    expect(find.text('Yenidən cəhd et'), findsOneWidget);
  });
}
