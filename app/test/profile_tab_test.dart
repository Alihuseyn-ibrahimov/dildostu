import 'package:dildostu/src/ui/profile_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  VoidCallback? onLogout,
  Future<void> Function()? onDeleteAccount,
}) =>
    MaterialApp(
      home: ProfileTab(
        onOpenSettings: () {},
        onOpenLearned: () {},
        onOpenRoutine: () {},
        onTestNotification: () {},
        email: 'ali@example.com',
        onLogout: onLogout ?? () {},
        onDeleteAccount: onDeleteAccount ?? () async {},
      ),
    );

void main() {
  testWidgets('e-poçt göstərilir', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('ali@example.com'), findsOneWidget);
  });

  testWidgets('Çıxış toxunulanda onLogout çağırılır', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(onLogout: () => called = true));
    await tester.tap(find.text('Çıxış'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
  });

  testWidgets('Hesabı sil təsdiq dialoqu açır, ləğv etsə çağırmır', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(onDeleteAccount: () async => called = true));
    await tester.tap(find.text('Hesabı sil'));
    await tester.pumpAndSettle();

    expect(find.textContaining('geri qaytarıla bilməz'), findsOneWidget);
    await tester.tap(find.text('Ləğv et'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('Hesabı sil təsdiqlənəndə onDeleteAccount çağırılır', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(onDeleteAccount: () async => called = true));
    await tester.tap(find.text('Hesabı sil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });
}
