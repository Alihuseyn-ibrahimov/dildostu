import 'package:dildostu/src/models/live_message.dart';
import 'package:dildostu/src/services/speaker.dart';
import 'package:dildostu/src/ui/live_card_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpeaker implements Speaker {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

LiveMessage _msg(String word, {bool isLive = true}) => LiveMessage(
      packId: 'cafe',
      word: word,
      translationAz: 'söz',
      ipa: '/x/',
      example: 'Example.',
      exampleAz: 'Nümunə.',
      aiLine: 'İndi kafedəsən!',
      level: 1,
      isLive: isLive,
    );

void main() {
  testWidgets('yüklənmədən sonra AI sətri və sözü göstərir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiveCardScreen(
        title: 'Kafedə',
        speaker: FakeSpeaker(),
        fetch: (mode) async => _msg('coffee'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('İndi kafedəsən!'), findsOneWidget);
    expect(find.text('coffee'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsNothing); // canlı → offline işarəsi yox
  });

  testWidgets('Sadələşdir düyməsi fetch-i simpler mode ilə çağırır', (tester) async {
    final modes = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: LiveCardScreen(
        title: 'Kafedə',
        speaker: FakeSpeaker(),
        fetch: (mode) async {
          modes.add(mode);
          return _msg('coffee');
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sadələşdir'));
    await tester.pumpAndSettle();

    expect(modes, ['normal', 'simpler']);
  });

  testWidgets('offline mesaj üçün cloud_off işarəsi göstərir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiveCardScreen(
        title: 'Kafedə',
        speaker: FakeSpeaker(),
        fetch: (mode) async => _msg('coffee', isLive: false),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });
}
