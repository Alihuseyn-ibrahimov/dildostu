import 'package:dildostu/src/models/user_profile.dart';
import 'package:dildostu/src/ui/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('formu doldurub Başla → düzgün profil qaytarır', (tester) async {
    // Dil seçicisi əlavə olunandan sonra form standart test viewport-undan
    // (800x600) uzundur — "Başla" ListView-in cache extent-indən kənara
    // düşməsin deyə (yoxsa `find` onu tapmır), viewport-u böyüdürük.
    await tester.binding.setSurfaceSize(const Size(400, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    UserProfile? result;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onComplete: (p) => result = p),
    ));

    // Defolt: travel + beginner. "İş" və "Orta" seçək.
    await tester.tap(find.text('İş'));
    await tester.tap(find.text('Orta'));
    await tester.enterText(find.byType(TextField), 'yemək, idman');
    await tester.tap(find.text('Başla'));
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.purpose, LearningPurpose.work);
    expect(result!.level, ProficiencyLevel.intermediate);
    expect(result!.interests, ['yemək', 'idman']);
    expect(result!.targetLang, TargetLanguage.english);
  });

  testWidgets('dil seçicisi görünür, seçim profilə düşür', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    UserProfile? result;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onComplete: (p) => result = p),
    ));

    expect(find.text('Hansı dili öyrənmək istəyirsən?'), findsOneWidget);
    await tester.tap(find.text('Rus'));
    await tester.tap(find.text('Başla'));
    await tester.pump();

    expect(result!.targetLang, TargetLanguage.russian);
  });
}
