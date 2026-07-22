import 'package:dildostu/src/models/user_profile.dart';
import 'package:dildostu/src/ui/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('formu doldurub Başla → düzgün profil qaytarır', (tester) async {
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
  });
}
