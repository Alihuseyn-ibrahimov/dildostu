import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/app_version_info.dart';

// /app/version — kiçik JSON cavabı, tez olmalıdır.
const _versionTimeout = Duration(seconds: 20);
// /app/latest.apk — 150+ MB fayl. Mobil/orta sürətli Wi-Fi-də tam yüklənmə
// bir neçə dəqiqə çəkə bilər; 20s kimi qısa vaxt demək olar həmişə vaxtından
// əvvəl kəsib "yeniləmə yoxdur" kimi görünürdü (səssiz uğursuzluq — banner
// heç görünmürdü). Böyük fayl üçün geniş büdcə verilir.
const _downloadTimeout = Duration(minutes: 5);

/// Serverdəki ən son buraxılışı yoxlayır və APK-nı yükləyir. Xəta halında
/// (server yoxdur, buraxılış yoxdur, şəbəkə xətası) səssiz keçir — yeniləmə
/// yoxlaması istifadəçini bloklamamalıdır.
class AppUpdateClient {
  AppUpdateClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<AppVersionInfo?> fetchVersionInfo() async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/app/version'))
          .timeout(_versionTimeout);
      if (resp.statusCode != 200) return null;
      final body =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      return AppVersionInfo.fromServerJson(body);
    } catch (_) {
      return null;
    }
  }

  /// APK-nı `destPath`-ə yükləyir; uğursuzsa null qaytarır (atmır).
  ///
  /// AXIN kimi yüklənir (`send()` + çanaq-çanaq yazma), `get()...bodyBytes` YOX —
  /// APK 150+ MB olduğu üçün bütün faylı yaddaşa yükləmək telefonda (xüsusən
  /// zəif cihazlarda) səssiz OOM-a səbəb ola bilirdi: xəta `catch`-ə düşür,
  /// "Yenilə" zolağı heç görünmürdü, amma heç bir xəta da göstərilmirdi.
  ///
  /// `onProgress(received, total)` hər çanaqdan sonra çağırılır (`total` server
  /// `Content-Length` verməsə null) — UI faizi göstərsin deyə: uzun yükləmə
  /// zamanı istifadəçi nəyinsə baş verdiyini görməlidir.
  Future<String?> downloadApk(
    String destPath, {
    void Function(int received, int? total)? onProgress,
  }) async {
    try {
      return await _downloadStreamed(destPath, onProgress)
          .timeout(_downloadTimeout);
    } catch (_) {
      // Yarımçıq fayl qalmasın — sonra quraşdırma cəhdi anlaşılmaz xəta versin.
      try {
        final f = File(destPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      return null;
    }
  }

  Future<String?> _downloadStreamed(
    String destPath,
    void Function(int received, int? total)? onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse('$baseUrl/app/latest.apk'));
    final streamed = await _http.send(request);
    if (streamed.statusCode != 200) return null;
    final total = streamed.contentLength;
    var received = 0;
    final sink = File(destPath).openWrite();
    try {
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return destPath;
  }
}
