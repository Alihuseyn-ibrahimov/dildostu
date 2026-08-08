import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sessiya məlumatının saxlanma abstraksiyası — testdə in-memory, prod-da
/// encrypted storage.
abstract class SessionStorage {
  Future<String?> readToken();
  Future<String?> readEmail();
  Future<void> writeSession({required String token, required String email});
  Future<void> clear();
}

/// Production: Android EncryptedSharedPreferences / Keychain.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'dildostu.auth.token.v2';
  static const _emailKey = 'dildostu.auth.email.v2';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<String?> readEmail() => _storage.read(key: _emailKey);

  @override
  Future<void> writeSession(
      {required String token, required String email}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _emailKey, value: email);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
  }
}

/// Test və unit testlər üçün yaddaşda saxlama.
class InMemorySessionStorage implements SessionStorage {
  String? token;
  String? email;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> writeSession(
      {required String token, required String email}) async {
    this.token = token;
    this.email = email;
  }

  @override
  Future<void> clear() async {
    token = null;
    email = null;
  }
}
