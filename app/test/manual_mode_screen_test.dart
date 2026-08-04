import 'package:dildostu/src/data/manual_context_repository.dart';
import 'package:dildostu/src/data/pack_repository.dart';
import 'package:dildostu/src/data/review_repository.dart';
import 'package:dildostu/src/services/speaker.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/manual_mode_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSpeaker implements Speaker {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('hər paket sətri öz aksent rənginə malikdir', (tester) async {
    final reviews = await ReviewRepository.load();
    final manualContext = await ManualContextRepository.load();
    await tester.pumpWidget(MaterialApp(
      home: ManualModeScreen(
        packRepository: PackRepository.fromJsonStrings([_cafePackJson]),
        reviewRepository: reviews,
        manualContextRepository: manualContext,
        speaker: FakeSpeaker(),
      ),
    ));

    final avatar =
        tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.backgroundColor, accentFor('cafe').tint);
  });
}
