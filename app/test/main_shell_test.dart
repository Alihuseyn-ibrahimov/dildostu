import 'package:dildostu/src/ui/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget shell() => const MaterialApp(
        home: MainShell(
          home: Center(child: Text('HOME-BODY')),
          chat: Center(child: Text('CHAT-BODY')),
          progress: Center(child: Text('PROGRESS-BODY')),
          profile: Center(child: Text('PROFILE-BODY')),
        ),
      );

  testWidgets('ilkin tab Ana səhifədir', (tester) async {
    await tester.pumpWidget(shell());
    expect(find.text('HOME-BODY'), findsOneWidget);
    // 4 naviqasiya bəndi görünür
    expect(find.text('Ana səhifə'), findsOneWidget);
    expect(find.text('Söhbət'), findsOneWidget);
    expect(find.text('İrəliləyiş'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('Söhbət tabına keçid gövdəni dəyişir', (tester) async {
    await tester.pumpWidget(shell());
    await tester.tap(find.text('Söhbət'));
    await tester.pumpAndSettle();
    expect(find.text('CHAT-BODY'), findsOneWidget);
  });

  testWidgets('Profil tabına keçid işləyir', (tester) async {
    await tester.pumpWidget(shell());
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE-BODY'), findsOneWidget);
  });

  testWidgets('IndexedStack tab vəziyyətini saxlayır (gövdə həmişə ağacda)',
      (tester) async {
    await tester.pumpWidget(shell());
    // IndexedStack bütün tabları ağacda saxlayır (offstage) — söhbət init olunub
    expect(find.text('CHAT-BODY', skipOffstage: false), findsOneWidget);
  });
}
