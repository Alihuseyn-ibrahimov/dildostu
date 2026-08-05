import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/user_profile.dart';

const _timeout = Duration(seconds: 20);
const _maxHistory = 12;

/// Söhbət serverə çatmadıqda və ya xəta qaytardıqda atılır.
class ChatException implements Exception {
  const ChatException(this.message);
  final String message;
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
      throw ChatException('Server xətası (${resp.statusCode})');
    } on ChatException {
      rethrow;
    } catch (e) {
      throw ChatException('Bağlantı yoxdur');
    }
  }
}
