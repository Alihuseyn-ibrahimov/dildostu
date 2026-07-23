import 'package:dildostu/src/data/pack_repository.dart';
import 'package:dildostu/src/models/user_profile.dart';
import 'package:dildostu/src/ui/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = UserProfile(
  wakeHour: 8,
  sleepHour: 23,
  purpose: LearningPurpose.travel,
  level: ProficiencyLevel.beginner,
  interests: [],
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
    required void Function(String, String, UserProfile) openLive,
    required VoidCallback onManualPlace,
  }) {
    return MaterialApp(
      home: HomeTab(
        repository: PackRepository.fromJsonStrings([_cafePackJson]),
        profile: _profile,
        openLive: openLive,
        onManualPlace: onManualPlace,
      ),
    );
  }

  testWidgets('salamlama, kontekst kartı və paket görünür', (tester) async {
    await tester.pumpWidget(wrap(openLive: (_, _, _) {}, onManualPlace: () {}));
    expect(find.text('Salam 👋'), findsOneWidget);
    expect(find.text('İndi haradayam?'), findsOneWidget);
    expect(find.text('Kafedə'), findsOneWidget);
    expect(find.text('1 söz'), findsOneWidget);
  });

  testWidgets('kontekst kartına toxunma onManualPlace çağırır', (tester) async {
    var called = false;
    await tester
        .pumpWidget(wrap(openLive: (_, _, _) {}, onManualPlace: () => called = true));
    await tester.tap(find.text('İndi haradayam?'));
    expect(called, isTrue);
  });

  testWidgets('paket kartına toxunma openLive çağırır', (tester) async {
    String? openedPack;
    await tester.pumpWidget(wrap(
        openLive: (packId, _, _) => openedPack = packId, onManualPlace: () {}));
    await tester.tap(find.text('Kafedə'));
    expect(openedPack, 'cafe');
  });
}
