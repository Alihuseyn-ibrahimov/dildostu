import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/audiobook.dart';

const _timeout = Duration(seconds: 15);

/// Səsli kitab kitabxanasını serverdən alır.
///
/// Audio faylının ÖZÜ buradan yüklənmir — plyer (native MediaPlayer) URL-i
/// birbaşa axınla oxuyur, offline üçün isə `AudiobookDownloader` işlədilir.
class AudiobookClient {
  AudiobookClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Kitabxana siyahısı. Xəta halında istisna atır (`null` qaytarmır) —
  /// çağıran ekran istifadəçiyə səbəbi göstərməlidir, səssiz boş siyahı yox.
  Future<List<Audiobook>> fetchLibrary() async {
    final raw = await fetchLibraryRaw();
    return parseLibrary(raw);
  }

  /// Kitabxananın xam JSON mətni (offline keş üçün — bax `AudiobookDownloader.
  /// cacheLibraryRaw`). Xəta halında istisna atır.
  Future<String> fetchLibraryRaw() async {
    final resp = await _http
        .get(Uri.parse('$baseUrl/audiobooks'))
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw StateError('Kitabxana yüklənmədi (${resp.statusCode})');
    }
    return utf8.decode(resp.bodyBytes);
  }

  /// Xam JSON mətnini kitab siyahısına çevirir — server cavabı ilə keşlənmiş
  /// yerli mətn üçün eyni parsing (bax `main.dart`-dakı offline fallback).
  static List<Audiobook> parseLibrary(String raw) {
    final body = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final b in (body['books'] as List? ?? const []))
        Audiobook.fromServerJson(b as Map<String, dynamic>),
    ];
  }

  /// Fəslin axın URL-i (native plyer birbaşa bunu oxuyur; endirmə də bu
  /// URL-dən istifadə edir, bax `AudiobookDownloader.downloadAll`).
  String chapterUrl(String bookId, String chapterId) =>
      '$baseUrl/audiobooks/$bookId/$chapterId.mp3';
}
