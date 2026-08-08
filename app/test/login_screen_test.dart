import 'package:dildostu/src/data/auth_client.dart';
import 'package:dildostu/src/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'locale_test_harness.dart';

void main() {
  Future<void> fillForm(WidgetTester tester,
      {String email = 'ali@example.com', String password = 'Parol1234'}) async {
    await tester.enterText(find.byKey(const Key('login_email')), email);
    await tester.enterText(find.byKey(const Key('login_password')), password);
  }

  testWidgets('defolt rejim Giriş — Qeydiyyat düyməsi görünür', (tester) async {
    await tester.pumpWidget(wrapWithLocale(LoginScreen(
      register: (_, _) async => const AuthResult(token: 't', email: 'a@b.com'),
      login: (_, _) async => const AuthResult(token: 't', email: 'a@b.com'),
      onAuthenticated: (_, _) {},
    )));

    expect(find.text('Giriş'), findsWidgets);
    expect(find.text('Hesabın yoxdur? Qeydiyyatdan keç'), findsOneWidget);
  });

  testWidgets('uğurlu giriş onAuthenticated çağırır', (tester) async {
    String? gotToken;
    String? gotEmail;
    await tester.pumpWidget(wrapWithLocale(LoginScreen(
      register: (_, _) async => throw UnimplementedError(),
      login: (email, password) async {
        expect(email, 'ali@example.com');
        expect(password, 'Parol1234');
        return const AuthResult(token: 'tok1', email: 'ali@example.com');
      },
      onAuthenticated: (token, email) {
        gotToken = token;
        gotEmail = email;
      },
    )));

    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş'));
    await tester.pumpAndSettle();

    expect(gotToken, 'tok1');
    expect(gotEmail, 'ali@example.com');
  });

  testWidgets('xəta mesajı göstərilir', (tester) async {
    await tester.pumpWidget(wrapWithLocale(LoginScreen(
      register: (_, _) async => throw UnimplementedError(),
      login: (_, _) async =>
          throw const AuthException('E-poçt və ya şifrə səhvdir.'),
      onAuthenticated: (_, _) {},
    )));

    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş'));
    await tester.pumpAndSettle();

    expect(find.text('E-poçt və ya şifrə səhvdir.'), findsOneWidget);
  });

  testWidgets('rejim dəyişəndə Qeydiyyat düyməsi görünür', (tester) async {
    await tester.pumpWidget(wrapWithLocale(LoginScreen(
      register: (_, _) async => const AuthResult(token: 't', email: 'a@b.com'),
      login: (_, _) async => const AuthResult(token: 't', email: 'a@b.com'),
      onAuthenticated: (_, _) {},
    )));

    await tester.tap(find.text('Hesabın yoxdur? Qeydiyyatdan keç'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Qeydiyyatdan keç'), findsOneWidget);
  });

  testWidgets('qeydiyyat rejimində register çağırılır (login yox)', (tester) async {
    var registerCalled = false;
    var loginCalled = false;
    await tester.pumpWidget(wrapWithLocale(LoginScreen(
      register: (_, _) async {
        registerCalled = true;
        return const AuthResult(token: 't', email: 'a@b.com');
      },
      login: (_, _) async {
        loginCalled = true;
        return const AuthResult(token: 't', email: 'a@b.com');
      },
      onAuthenticated: (_, _) {},
    )));

    await tester.tap(find.text('Hesabın yoxdur? Qeydiyyatdan keç'));
    await tester.pumpAndSettle();
    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Qeydiyyatdan keç'));
    await tester.pumpAndSettle();

    expect(registerCalled, isTrue);
    expect(loginCalled, isFalse);
  });

  testWidgets('boş e-poçt/şifrə ilə submit etmir', (tester) async {
    var called = false;
    await tester.pumpWidget(wrapWithLocale(LoginScreen(
      register: (_, _) async => const AuthResult(token: 't', email: 'a@b.com'),
      login: (_, _) async {
        called = true;
        return const AuthResult(token: 't', email: 'a@b.com');
      },
      onAuthenticated: (_, _) {},
    )));

    await tester.tap(find.widgetWithText(FilledButton, 'Giriş'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });
}
