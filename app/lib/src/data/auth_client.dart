import 'dart:convert';

import 'package:http/http.dart' as http;

const _timeout = Duration(seconds: 10);

/// Giriş/qeydiyyat uğursuz olanda atılır. `message` istifadəçiyə birbaşa
/// göstərilə bilən Azərbaycanca mətndir.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Uğurlu qeydiyyat/giriş nəticəsi.
class AuthResult {
  const AuthResult({required this.token, required this.email});
  final String token;
  final String email;
}

/// Server-in `/auth/*` endpoint-ləri ilə danışan təmiz qat.
///
/// Digər client-lərdən fərqli olaraq (RoutineClient, PlaceClient) xətaları
/// SƏSSİZ udmur — giriş/qeydiyyat uğursuzluğu istifadəçiyə göstərilməlidir,
/// ona görə `AuthException` atır (ekran onu tutub mesaj göstərir).
class AuthClient {
  AuthClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<AuthResult> register(String email, String password) =>
      _authRequest('/auth/register', email, password);

  Future<AuthResult> login(String email, String password) =>
      _authRequest('/auth/login', email, password);

  Future<AuthResult> _authRequest(
      String path, String email, String password) async {
    http.Response resp;
    try {
      resp = await _http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const AuthException(
          'Bağlantı xətası — internetini yoxla və yenidən cəhd et.');
    }

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final user = body['user'] as Map<String, dynamic>;
      return AuthResult(
        token: body['token'] as String,
        email: user['email'] as String,
      );
    }
    throw AuthException(_messageFor(resp.statusCode));
  }

  String _messageFor(int statusCode) {
    switch (statusCode) {
      case 409:
        return 'Bu e-poçt artıq qeydiyyatdadır. Giriş etməyi sınayın.';
      case 401:
        return 'E-poçt və ya şifrə səhvdir.';
      case 422:
        return 'E-poçt düzgün deyil və ya şifrə çox qısadır (ən azı 8 simvol).';
      default:
        return 'Xəta baş verdi ($statusCode). Yenidən cəhd et.';
    }
  }

  Future<void> deleteAccount(String token) async {
    http.Response resp;
    try {
      resp = await _http
          .delete(
            Uri.parse('$baseUrl/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
    } catch (_) {
      throw const AuthException(
          'Bağlantı xətası — internetini yoxla və yenidən cəhd et.');
    }
    if (resp.statusCode != 204) {
      throw AuthException(_messageFor(resp.statusCode));
    }
  }

  /// Token hələ etibarlıdırmı — app açılışında yoxlanır.
  /// 401 → false (logout). Şəbəkə/500 → true (offline saxla).
  Future<bool> validateSession(String token) async {
    try {
      final resp = await _http
          .get(
            Uri.parse('$baseUrl/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (resp.statusCode == 401) return false;
      return true;
    } catch (_) {
      return true;
    }
  }
}
