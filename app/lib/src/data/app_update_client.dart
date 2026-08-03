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
  Future<String?> downloadApk(String destPath) async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/app/latest.apk'))
          .timeout(_downloadTimeout);
      if (resp.statusCode != 200) return null;
      await File(destPath).writeAsBytes(resp.bodyBytes);
      return destPath;
    } catch (_) {
      return null;
    }
  }
}
