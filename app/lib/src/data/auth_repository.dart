import 'package:shared_preferences/shared_preferences.dart';

import 'session_storage.dart';

// Köhnə plain-text açarlar — miqrasiya üçün (v67 və əvvəl).
const _legacyTokenKey = 'dildostu.auth.token.v1';
const _legacyEmailKey = 'dildostu.auth.email.v1';

/// Giriş sessiyasını (token + e-poçt) cihazda saxlayır.
///
/// v68+: token `flutter_secure_storage`-də (encrypted). Köhnə
/// `SharedPreferences` dəyərləri ilk yükləmədə avtomatik köçürülür.
class AuthRepository {
  AuthRepository._(this._storage, this.token, this.email);

  final SessionStorage _storage;
  String? token;
  String? email;

  bool get isLoggedIn => token != null;

  String? get authHeader => token == null ? null : 'Bearer $token';

  /// [storageForTest] yalnız testlər üçün — prod-da secure storage işlədilir.
  static Future<AuthRepository> load({SessionStorage? storageForTest}) async {
    final storage = storageForTest ?? SecureSessionStorage();
    await _migrateLegacySession(storage);
    final token = await storage.readToken();
    final email = await storage.readEmail();
    return AuthRepository._(storage, token, email);
  }

  /// v1 SharedPreferences → v2 secure storage (APK yeniləməsindən sonra sessiya
  /// itməsin deyə).
  static Future<void> _migrateLegacySession(SessionStorage storage) async {
    final existing = await storage.readToken();
    if (existing != null) return;

    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_legacyTokenKey);
    if (legacyToken == null || legacyToken.isEmpty) return;

    final legacyEmail = prefs.getString(_legacyEmailKey) ?? '';
    await storage.writeSession(token: legacyToken, email: legacyEmail);
    await prefs.remove(_legacyTokenKey);
    await prefs.remove(_legacyEmailKey);
  }

  Future<void> setSession({required String token, required String email}) async {
    this.token = token;
    this.email = email;
    await _storage.writeSession(token: token, email: email);
  }

  Future<void> logout() async {
    token = null;
    email = null;
    await _storage.clear();
  }
}
