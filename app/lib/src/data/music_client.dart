import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/song.dart';

const _timeout = Duration(seconds: 15);

/// Musiqi kataloqunu serverdən alır.
///
/// Audio faylının ÖZÜ buradan yüklənmir — video YouTube-dan proqram daxilində
/// embed olunur (bax `audiobook_client.dart`-ın eyni prinsipinin qohumu).
class MusicClient {
  MusicClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Mahnı kataloqu. Xəta halında istisna atır (`null` qaytarmır) —
  /// çağıran ekran istifadəçiyə səbəbi göstərməlidir, səssiz boş siyahı yox.
  Future<List<Song>> fetchLibrary() async {
    final resp =
        await _http.get(Uri.parse('$baseUrl/music')).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw StateError('Musiqi kataloqu yüklənmədi (${resp.statusCode})');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final s in (body['songs'] as List? ?? const []))
        Song.fromServerJson(s as Map<String, dynamic>),
    ];
  }
}
