import 'dart:convert';

import 'package:http/http.dart' as http;

const _timeout = Duration(seconds: 15);

/// Toxunulan sözün AZ mənası.
class WordLookupResult {
  const WordLookupResult({
    required this.word,
    required this.translationAz,
    required this.ipa,
  });

  final String word;
  final String translationAz;
  final String ipa;

  factory WordLookupResult.fromServerJson(Map<String, dynamic> json) =>
      WordLookupResult(
        word: json['word'] as String,
        translationAz: json['translation_az'] as String,
        ipa: json['ipa'] as String,
      );
}

/// Səsli kitab mətnində toxunulan sözün mənasını serverdən alır.
///
/// `context` sözün keçdiyi cümlədir — düzgün məna üçün AI-yə ötürülür
/// (məs. "bank" çay sahili/bank fərqi).
class WordLookupClient {
  WordLookupClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Xəta halında istisna atır (səssiz `null` qaytarmır) — çağıran ekran
  /// istifadəçiyə səbəbi göstərməlidir.
  Future<WordLookupResult> lookup(String word, {String context = ''}) async {
    final resp = await _http
        .post(
          Uri.parse('$baseUrl/word-lookup'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'word': word, 'context': context}),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw StateError('Söz tapılmadı (${resp.statusCode})');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return WordLookupResult.fromServerJson(body);
  }
}
