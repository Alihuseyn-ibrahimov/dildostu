import 'package:dildostu/src/data/pack_repository.dart';

import 'package:dildostu/src/data/review_repository.dart';

import 'package:dildostu/src/engine/review_engine.dart';

import 'package:dildostu/src/models/live_message.dart';

import 'package:dildostu/src/services/speaker.dart';

import 'package:dildostu/src/ui/progress_tab.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';



import 'locale_test_harness.dart';



class _FakeSpeaker implements Speaker {

  @override

  Future<void> speak(String text) async {}



  @override

  Future<void> stop() async {}



  @override

  Future<void> dispose() async {}

}



void main() {

  TestWidgetsFlutterBinding.ensureInitialized();



  setUp(() {

    SharedPreferences.setMockInitialValues({});

  });



  testWidgets('irəliləyiş tabı statistikaları göstərir', (tester) async {

    final repo = await ReviewRepository.load();

    final now = DateTime(2026, 8, 6, 12);

    await repo.recordExposure(

      'cafe:coffee',

      now: now,

      hint: LiveMessage(

        packId: 'cafe',

        word: 'coffee',

        translationAz: 'qəhvə',

        ipa: '/k/',

        example: 'Coffee',

        exampleAz: 'Qəhvə',

        aiLine: 'line',

        level: 1,

        isLive: false,

      ),

    );

    await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: now);



    final packs = PackRepository.fromJsonStrings([

      '''

{

  "pack_id": "cafe", "target_lang": "en", "ui_lang": "az", "title_az": "Kafe",

  "words": [

    {"word": "coffee", "translation_az": "qəhvə", "ipa": "/k/",

     "example": "A coffee.", "example_az": "Bir qəhvə.", "level": 1}

  ]

}

''',

    ]);



    await tester.pumpWidget(wrapWithLocale(ProgressTab(

      reviewRepository: repo,

      packRepository: packs,

      speaker: _FakeSpeaker(),

    )));



    expect(find.text('İrəliləyiş'), findsOneWidget);

    expect(find.text('Kəşf etdin'), findsOneWidget);

    expect(find.text('Öyrənirsən'), findsOneWidget);

    expect(find.text('Mənimsədin'), findsOneWidget);

    expect(find.text('Son 7 gün'), findsOneWidget);

  });

}

