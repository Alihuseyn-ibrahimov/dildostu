import 'package:dildostu/src/data/auth_repository.dart';
import 'package:dildostu/src/data/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SessionStorage storage() => InMemorySessionStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('token yoxdursa isLoggedIn false', () async {
    final auth = await AuthRepository.load(storageForTest: storage());
    expect(auth.isLoggedIn, isFalse);
    expect(auth.token, isNull);
  });

  test('setSession sonra isLoggedIn true və token saxlanır', () async {
    final auth = await AuthRepository.load(storageForTest: storage());
    await auth.setSession(token: 'tok123', email: 'ali@example.com');
    expect(auth.isLoggedIn, isTrue);
    expect(auth.token, 'tok123');
    expect(auth.email, 'ali@example.com');
  });

  test('token disk-də qalır — yenidən yükləyəndə tapılır', () async {
    final mem = storage();
    final first = await AuthRepository.load(storageForTest: mem);
    await first.setSession(token: 'tok123', email: 'ali@example.com');

    final second = await AuthRepository.load(storageForTest: mem);
    expect(second.isLoggedIn, isTrue);
    expect(second.token, 'tok123');
    expect(second.email, 'ali@example.com');
  });

  test('logout token-i silir', () async {
    final auth = await AuthRepository.load(storageForTest: storage());
    await auth.setSession(token: 'tok123', email: 'ali@example.com');
    await auth.logout();
    expect(auth.isLoggedIn, isFalse);
    expect(auth.token, isNull);
  });

  test('logout sonra disk-də də yoxdur', () async {
    final mem = storage();
    final first = await AuthRepository.load(storageForTest: mem);
    await first.setSession(token: 'tok123', email: 'ali@example.com');
    await first.logout();

    final second = await AuthRepository.load(storageForTest: mem);
    expect(second.isLoggedIn, isFalse);
  });

  test('authHeader Bearer formatındadır', () async {
    final auth = await AuthRepository.load(storageForTest: storage());
    await auth.setSession(token: 'tok123', email: 'ali@example.com');
    expect(auth.authHeader, 'Bearer tok123');
  });

  test('giriş yoxdursa authHeader null', () async {
    final auth = await AuthRepository.load(storageForTest: storage());
    expect(auth.authHeader, isNull);
  });

  test('legacy SharedPreferences miqrasiya olunur', () async {
    SharedPreferences.setMockInitialValues({
      'dildostu.auth.token.v1': 'legacy-tok',
      'dildostu.auth.email.v1': 'a@b.com',
    });
    final mem = InMemorySessionStorage();
    final auth = await AuthRepository.load(storageForTest: mem);
    expect(auth.token, 'legacy-tok');
    expect(auth.email, 'a@b.com');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dildostu.auth.token.v1'), isNull);
  });
}
