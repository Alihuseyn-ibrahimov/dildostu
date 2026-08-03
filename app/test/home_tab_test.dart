import 'package:dildostu/src/data/pack_repository.dart';
import 'package:dildostu/src/models/user_profile.dart';
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
    DateTime? now,
  }) {
    return MaterialApp(
      home: HomeTab(
        repository: PackRepository.fromJsonStrings([_cafePackJson]),
        profile: _profile(level: level),
        openLive: openLive ?? (_, _, _) {},
        onManualPlace: onManualPlace ?? () {},
        onLevelChanged: onLevelChanged,
        now: now,
      ),
    );
  }

  group('greetingFor', () {
    test('gecə / səhər / günorta / axşam', () {
      expect(greetingFor(DateTime(2026, 8, 3, 3)), 'Gecən xeyrə');
      expect(greetingFor(DateTime(2026, 8, 3, 9)), 'Sabahın xeyir');
      expect(greetingFor(DateTime(2026, 8, 3, 14)), 'Günortan xeyir');
      expect(greetingFor(DateTime(2026, 8, 3, 21)), 'Axşamın xeyir');
    });
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
    await tester.tap(find.text('Kafedə'));
    expect(openedPack, 'cafe');
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
}
