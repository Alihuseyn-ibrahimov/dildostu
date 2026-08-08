import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/chat_nudge.dart';
import '../models/chat_quota.dart';
import '../models/user_profile.dart';

const _timeout = Duration(seconds: 45);
const _maxHistory = 12;

/// Söhbət xətasının növü — UI hər biri üçün fərqli mesaj/əməliyyat göstərir
/// (yenidən cəhd yalnız keçici xətalarda mənalıdır).
enum ChatErrorKind {
  /// Şəbəkə yoxdur və ya server cavab vermir.
  network,

  /// Gündəlik söhbət limiti dolub (server 429).
  quota,

  /// AI provayderləri uğursuz oldu (server 502) — keçici.
  aiUnavailable,

  /// Sessiya bitib (401) — yenidən giriş lazımdır.
  unauthorized,

  /// Digər gözlənilməz server cavabı.
  unknown,
}

/// Söhbət serverə çatmadıqda və ya xəta qaytardıqda atılır.
class ChatException implements Exception {
  const ChatException(this.message, {this.kind = ChatErrorKind.unknown});

  final String message;
  final ChatErrorKind kind;

  /// Yenidən cəhd etmək mənalıdırmı (limit/sessiya xətasında yox).
  bool get isRetryable =>
      kind == ChatErrorKind.network || kind == ChatErrorKind.aiUnavailable;

  @override
  String toString() => 'ChatException: $message';
}

/// AI söhbət serverinə (`/chat`) sorğu göndərir. Söhbət offline işləmir —
/// xəta halında ChatException atır (UI diskret mesaj göstərir).
///
/// `/chat` və `/chat/history` autentifikasiya tələb edir (bax spec:
/// 2026-08-04-chat-memory-design.md) — yaddaş `user_id`-yə bağlıdır.
class ChatClient {
  ChatClient({required this.baseUrl, required this.token, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _http;

  Map<String, String> get _authHeaders => {'Authorization': 'Bearer $token'};

  /// Saxlanmış çat tarixçəsini gətirir (ekran açılanda göstərmək üçün).
  /// Xəta halında boş siyahı — tarixçə göstərilə bilməsə belə söhbət davam
  /// etməlidir, UI-nı bloklamır.
  Future<List<ChatMessage>> fetchHistory() async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/chat/history'), headers: _authHeaders)
          .timeout(_timeout);
      if (resp.statusCode != 200) return const [];
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
      return [for (final m in messages) ChatMessage.fromServerJson(m)];
    } catch (_) {
      return const [];
    }
  }

  /// Söhbət tarixçəsini serverdə silir (portret qalır).
  Future<bool> clearHistory() => _delete('/chat/history');

  /// AI-nin istifadəçi haqqında yığdığı faktlar — Ayarlarda göstərilir.
  Future<List<String>> fetchPortrait() async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/chat/portrait'), headers: _authHeaders)
          .timeout(_timeout);
      if (resp.statusCode != 200) return const [];
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      return (body['facts'] as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  /// Portreti sıfırlayır — AI istifadəçini yenidən tanımağa başlayır.
  Future<bool> clearPortrait() => _delete('/chat/portrait');

  /// Gündəlik mesaj kvotası — limitə çatmadan xəbərdarlıq göstərmək üçün.
  /// Xəta halında null (söhbət bloklanmır).
  Future<ChatQuota?> fetchQuota() async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/chat/quota'), headers: _authHeaders)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      return ChatQuota.fromJson(body);
    } catch (_) {
      return null;
    }
  }

  /// Gündəlik proaktiv chat xatırlatmaları (AI-siz şablonlar).
  Future<List<ChatNudge>> fetchNudges() async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/chat/nudges'), headers: _authHeaders)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return const [];
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final nudges = (body['nudges'] as List).cast<Map<String, dynamic>>();
      return [for (final n in nudges) ChatNudge.fromJson(n)];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> _delete(String path) async {
    try {
      final resp = await _http
          .delete(Uri.parse('$baseUrl$path'), headers: _authHeaders)
          .timeout(_timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> send({
    required UserProfile profile,
    required List<ChatMessage> history,
    String? packId,
    int? hour,
  }) async {
    // Xərc nəzarəti: yalnız son _maxHistory mesaj.
    final trimmed = history.length > _maxHistory
        ? history.sublist(history.length - _maxHistory)
        : history;
    try {
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {..._authHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'profile': profile.toServerJson(),
              'messages': [for (final m in trimmed) m.toServerJson()],
              if (packId != null && hour != null)
                'context': {'pack_id': packId, 'hour': hour},
            }),
          )
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final body =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        return body['reply'] as String;
      }
      throw _errorFor(resp);
    } on ChatException {
      rethrow;
    } catch (_) {
      throw const ChatException(
        'İnternet bağlantısı yoxdur və ya server cavab vermir.',
        kind: ChatErrorKind.network,
      );
    }
  }

  /// Server statusunu istifadəçiyə göstərilən Azərbaycanca mesaja çevirir.
  /// 429-da serverin öz mətni (limit sayı ilə) üstün tutulur.
  ChatException _errorFor(http.Response resp) {
    switch (resp.statusCode) {
      case 429:
        return ChatException(
          _detail(resp) ?? 'Bu gün üçün söhbət limitin doldu. Sabah davam edək!',
          kind: ChatErrorKind.quota,
        );
      case 401:
        return const ChatException(
          'Sessiya bitib — yenidən giriş et.',
          kind: ChatErrorKind.unauthorized,
        );
      case 502:
      case 503:
        return const ChatException(
          'AI hazırda cavab verə bilmir. Bir azdan yenidən cəhd et.',
          kind: ChatErrorKind.aiUnavailable,
        );
      default:
        return ChatException(
          'Server xətası (${resp.statusCode})',
          kind: ChatErrorKind.unknown,
        );
    }
  }

  String? _detail(http.Response resp) {
    try {
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final detail = body['detail'];
      return detail is String && detail.isNotEmpty ? detail : null;
    } catch (_) {
      return null;
    }
  }
}
