import 'package:dildostu/src/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('token yoxdursa isLoggedIn false', () async {
    final auth = await AuthRepository.load();
    expect(auth.isLoggedIn, isFalse);
    expect(auth.token, isNull);
  });

  test('setSession sonra isLoggedIn true və token saxlanır', () async {
    final auth = await AuthRepository.load();
    await auth.setSession(token: 'tok123', email: 'ali@example.com');
    expect(auth.isLoggedIn, isTrue);
    expect(auth.token, 'tok123');
    expect(auth.email, 'ali@example.com');
  });

  test('token disk-də qalır — yenidən yükləyəndə tapılır', () async {
    final first = await AuthRepository.load();
    await first.setSession(token: 'tok123', email: 'ali@example.com');

    final second = await AuthRepository.load();
    expect(second.isLoggedIn, isTrue);
    expect(second.token, 'tok123');
    expect(second.email, 'ali@example.com');
  });

  test('logout token-i silir', () async {
    final auth = await AuthRepository.load();
    await auth.setSession(token: 'tok123', email: 'ali@example.com');
    await auth.logout();
    expect(auth.isLoggedIn, isFalse);
    expect(auth.token, isNull);
  });

  test('logout sonra disk-də də yoxdur', () async {
    final first = await AuthRepository.load();
    await first.setSession(token: 'tok123', email: 'ali@example.com');
    await first.logout();

    final second = await AuthRepository.load();
    expect(second.isLoggedIn, isFalse);
  });

  test('authHeader Bearer formatındadır', () async {
    final auth = await AuthRepository.load();
    await auth.setSession(token: 'tok123', email: 'ali@example.com');
    expect(auth.authHeader, 'Bearer tok123');
  });

  test('giriş yoxdursa authHeader null', () async {
    final auth = await AuthRepository.load();
    expect(auth.authHeader, isNull);
  });
}
