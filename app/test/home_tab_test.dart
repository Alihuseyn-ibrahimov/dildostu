import 'package:dildostu/src/l10n/app_locale_scope.dart';
import 'package:dildostu/src/l10n/app_strings.dart';
import 'package:dildostu/src/l10n/material_app_l10n.dart';
import 'package:dildostu/src/models/ui_language.dart';
import 'package:dildostu/src/data/pack_repository.dart';
import 'package:dildostu/src/models/live_message.dart';
import 'package:dildostu/src/models/user_profile.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile({ProficiencyLevel level = ProficiencyLevel.beginner}) =>
    UserProfile(
      wakeHour: 8,
      sleepHour: 23,
      purpose: LearningPurpose.travel,
      level: level,
      interests: const [],
    );

const _cafePackJson = '''
{
  "pack_id": "cafe", "target_lang": "en", "ui_lang": "az", "title_az": "Kafedə",
  "words": [
    {"word": "coffee", "translation_az": "qəhvə", "ipa": "/k/",
     "example": "A coffee.", "example_az": "Bir qəhvə.", "level": 1}
  ]
}
''';

void main() {
  Widget wrap({
    void Function(String, String, UserProfile)? openLive,
    VoidCallback? onManualPlace,
    ValueChanged<ProficiencyLevel>? onLevelChanged,
    ProficiencyLevel level = ProficiencyLevel.beginner,
    TargetLanguage? currentLanguage,
    ValueChanged<TargetLanguage>? onLanguageChanged,
    DateTime? now,
    ResolveLivePlace? resolveLivePlace,
    LoadDayPlan? loadDayPlan,
    OpenDayPlanWord? onOpenDayPlanWord,
    VoidCallback? onOpenMusic,
  }) {
    return AppLocaleScope(
      language: UiLanguage.az,
      strings: AppStrings(UiLanguage.az),
      child: MaterialApp(
        localizationsDelegates: MaterialAppL10n.localizationsDelegates,
        supportedLocales: MaterialAppL10n.supportedLocales,
        locale: MaterialAppL10n.locale,
        home: HomeTab(
        repository: PackRepository.fromJsonStrings([_cafePackJson]),
        profile: _profile(level: level),
        openLive: openLive ?? (_, _, _) {},
        onManualPlace: onManualPlace ?? () {},
        onLevelChanged: onLevelChanged,
        currentLanguage: currentLanguage,
        onLanguageChanged: onLanguageChanged,
        now: now,
        resolveLivePlace: resolveLivePlace,
        loadDayPlan: loadDayPlan,
        onOpenDayPlanWord: onOpenDayPlanWord,
        onOpenMusic: onOpenMusic,
        ),
      ),
    );
  }

  testWidgets('gündəlik missiya kartı sözləri göstərir', (tester) async {
    await tester.pumpWidget(wrap(
      loadDayPlan: ({forceRefresh = false}) async => (
        messages: [
          LiveMessage(
            packId: 'cafe',
            word: 'latte',
            translationAz: 'latte',
            ipa: '/l/',
            example: 'A latte.',
            exampleAz: 'Bir latte.',
            aiLine: 'Kafedəsən!',
            level: 1,
            isLive: true,
          ),
        ],
        isLive: true,
      ),
      onOpenDayPlanWord: (_, __) {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bu günün missiyası'), findsOneWidget);
    expect(find.text('latte'), findsOneWidget);
    expect(find.text('1 söz · AI ilə seçildi'), findsOneWidget);
  });

  testWidgets('salamlama, kontekst kartı və paket görünür', (tester) async {
    await tester.pumpWidget(wrap(now: DateTime(2026, 8, 3, 9)));
    expect(find.text('Sabahın xeyir'), findsOneWidget);
    expect(find.text('İndi haradayam?'), findsOneWidget);
    expect(find.text('Kafedə'), findsOneWidget);
    expect(find.text('1 söz · asan'), findsOneWidget);
  });

  testWidgets('kontekst kartına toxunma onManualPlace çağırır', (tester) async {
    var called = false;
    await tester.pumpWidget(wrap(onManualPlace: () => called = true));
    await tester.tap(find.text('İndi haradayam?'));
    expect(called, isTrue);
  });

  testWidgets('paket kartına toxunma openLive çağırır', (tester) async {
    String? openedPack;
    await tester.pumpWidget(wrap(openLive: (packId, _, _) => openedPack = packId));
    await tester.tap(find.byIcon(Icons.local_cafe));
    expect(openedPack, 'cafe');
  });

  testWidgets('paket kartının ikon plitəsi öz aksent rənginə malikdir',
      (tester) async {
    await tester.pumpWidget(wrap());
    final iconFinder = find.byIcon(Icons.local_cafe);
    expect(iconFinder, findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(of: iconFinder, matching: find.byType(Container)).first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, accentFor('cafe').tint);
  });

  group('çətinlik seçicisi', () {
    testWidgets('3 səviyyəni göstərir', (tester) async {
      await tester.pumpWidget(wrap(onLevelChanged: (_) {}));
      expect(find.text('Asan'), findsOneWidget);
      expect(find.text('Orta'), findsOneWidget);
      expect(find.text('Çətin'), findsOneWidget);
    });

    testWidgets('seçiləndə callback çağırılır', (tester) async {
      ProficiencyLevel? picked;
      await tester.pumpWidget(wrap(onLevelChanged: (l) => picked = l));
      await tester.tap(find.text('Çətin'));
      await tester.pumpAndSettle();
      expect(picked, ProficiencyLevel.advanced);
    });

    testWidgets('seçilmiş səviyyənin izahı görünür', (tester) async {
      await tester.pumpWidget(
          wrap(onLevelChanged: (_) {}, level: ProficiencyLevel.advanced));
      expect(find.text(ProficiencyLevel.advanced.hintAz), findsOneWidget);
    });

    testWidgets('onLevelChanged verilməyibsə göstərilmir', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.text('Çətinlik səviyyəsi'), findsNothing);
    });

    testWidgets('paket alt sətri cari səviyyəni əks etdirir', (tester) async {
      await tester.pumpWidget(
          wrap(onLevelChanged: (_) {}, level: ProficiencyLevel.intermediate));
      expect(find.text('1 söz · orta'), findsOneWidget);
    });
  });

  group('dil seçicisi (sağ yuxarı künc)', () {
    testWidgets('cari dil düymədə görünür', (tester) async {
      await tester.pumpWidget(wrap(
        currentLanguage: TargetLanguage.spanish,
        onLanguageChanged: (_) {},
      ));
      expect(find.text('Español'), findsOneWidget);
    });

    testWidgets('toxunanda bütün dillər siyahı kimi açılır', (tester) async {
      await tester.pumpWidget(wrap(
        currentLanguage: TargetLanguage.english,
        onLanguageChanged: (_) {},
      ));

      await tester.tap(find.byKey(const Key('home-language-picker')));
      await tester.pumpAndSettle();

      for (final lang in TargetLanguage.values) {
        expect(find.text(lang.nativeLabel), findsWidgets);
      }
    });

    testWidgets('dil seçiləndə callback çağırılır', (tester) async {
      TargetLanguage? picked;
      await tester.pumpWidget(wrap(
        currentLanguage: TargetLanguage.english,
        onLanguageChanged: (lang) => picked = lang,
      ));

      await tester.tap(find.byKey(const Key('home-language-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español').last);
      await tester.pumpAndSettle();

      expect(picked, TargetLanguage.spanish);
    });

    testWidgets('onLanguageChanged verilməyibsə göstərilmir', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.byKey(const Key('home-language-picker')), findsNothing);
    });
  });

  group('canlı məkan kartı (2026-08-07 dəqiqlik işi)', () {
    testWidgets('tapılan yer adı, paket, məsafə göstərilir', (tester) async {
      await tester.pumpWidget(wrap(
        resolveLivePlace: ({bool forceRefresh = false}) async =>
            LivePlaceState.resolved(
          packId: 'cafe',
          title: 'Kafedə',
          placeName: 'Kofe Evi',
          distanceM: 27,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kofe Evi'), findsOneWidget);
      expect(find.textContaining('27 m'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('uğursuzluqda SƏBƏB göstərilir, səssiz keçilmir',
        (tester) async {
      await tester.pumpWidget(wrap(
        resolveLivePlace: ({bool forceRefresh = false}) async =>
            LivePlaceState.failed(
                'Cihazda məkan xidməti söndürülüb — onu açıb yenidən yoxla.'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Yerini tapa bilmədim'), findsOneWidget);
      expect(find.textContaining('məkan xidməti söndürülüb'), findsOneWidget);
      expect(find.byIcon(Icons.location_disabled), findsOneWidget);
    });

    testWidgets('təxmini fix ayrı ikon və etiketlə göstərilir', (tester) async {
      await tester.pumpWidget(wrap(
        resolveLivePlace: ({bool forceRefresh = false}) async =>
            LivePlaceState.resolved(
          packId: 'cafe',
          title: 'Kafedə',
          placeName: 'Kofe Evi',
          approximate: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('təxmini'), findsOneWidget);
      expect(find.byIcon(Icons.location_searching), findsOneWidget);
    });

    testWidgets('paketi olmayan yer göstərilir, amma paket açmır',
        (tester) async {
      String? opened;
      var manualTapped = false;
      await tester.pumpWidget(wrap(
        openLive: (packId, _, _) => opened = packId,
        onManualPlace: () => manualTapped = true,
        resolveLivePlace: ({bool forceRefresh = false}) async =>
            LivePlaceState.resolved(placeName: 'Dənizkənarı Park'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dənizkənarı Park'), findsOneWidget);
      expect(find.textContaining('söz paketi yoxdur'), findsOneWidget);

      await tester.tap(find.text('Dənizkənarı Park'));
      expect(opened, isNull);
      expect(manualTapped, isTrue);
    });

    testWidgets('yenilə düyməsi keşi keçir (forceRefresh)', (tester) async {
      final refreshFlags = <bool>[];
      await tester.pumpWidget(wrap(
        resolveLivePlace: ({bool forceRefresh = false}) async {
          refreshFlags.add(forceRefresh);
          return LivePlaceState.resolved(
              packId: 'cafe', title: 'Kafedə', placeName: 'Kofe Evi');
        },
      ));
      await tester.pumpAndSettle();
      expect(refreshFlags, [false], reason: 'ilk yükləmə keşdən ola bilər');

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(refreshFlags, [false, true]);
    });

    testWidgets('tapılan paketə toxunma onu açır', (tester) async {
      String? opened;
      await tester.pumpWidget(wrap(
        openLive: (packId, _, _) => opened = packId,
        resolveLivePlace: ({bool forceRefresh = false}) async =>
            LivePlaceState.resolved(
                packId: 'cafe', title: 'Kafedə', placeName: 'Kofe Evi'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kofe Evi'));
      expect(opened, 'cafe');
    });
  });

  group('Musiqi kartı', () {
    testWidgets('callback veriləndə kart görünür', (tester) async {
      await tester.pumpWidget(wrap(onOpenMusic: () {}));
      await tester.pumpAndSettle();
      expect(find.text('Musiqi'), findsOneWidget);
    });

    testWidgets('callback null olanda kart GİZLİDİR (Play buraxılışı)',
        (tester) async {
      // Play buraxılışında lisenziyasız mahnı sözləri göstərilmir —
      // main.dart `isPlayBuild` olanda `onOpenMusic: null` ötürür
      // (bax .planning/2026-08-03-dildostu-playstore, tapıntı D).
      await tester.pumpWidget(wrap(onOpenMusic: null));
      await tester.pumpAndSettle();
      expect(find.text('Musiqi'), findsNothing);
    });
  });
}
