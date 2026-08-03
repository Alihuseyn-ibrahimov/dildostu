import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'dildostu.auth.token.v1';
const _emailKey = 'dildostu.auth.email.v1';

/// Giriş sessiyasını (token + e-poçt) cihazda saxlayır.
///
/// Token disk-də saxlanır ki, app bağlanıb açılanda istifadəçi yenidən giriş
/// etməsin. `_AuthGate` (main.dart) bunu app açılışında yükləyib
/// `isLoggedIn`-ə görə Login/əsas ekran arasında seçim edir.
class AuthRepository {
  AuthRepository._(this._prefs, this.token, this.email);

  final SharedPreferences _prefs;
  String? token;
  String? email;

  bool get isLoggedIn => token != null;

  /// HTTP sorğularında `Authorization` başlığı üçün. Giriş yoxdursa `null`.
  String? get authHeader => token == null ? null : 'Bearer $token';

  static Future<AuthRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthRepository._(
      prefs,
      prefs.getString(_tokenKey),
      prefs.getString(_emailKey),
    );
  }

  Future<void> setSession({required String token, required String email}) async {
    this.token = token;
    this.email = email;
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_emailKey, email);
  }

  Future<void> logout() async {
    token = null;
    email = null;
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_emailKey);
  }
}
