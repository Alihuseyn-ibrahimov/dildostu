import 'dart:convert';
import 'dart:io';

import 'package:dildostu/src/data/app_update_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetchVersionInfo 200-də parse edir', () async {
    final mock = MockClient((req) async => http.Response.bytes(
        utf8.encode(jsonEncode(
            {'version_code': 5, 'version_name': '1.0.0+5', 'notes': 'x'})),
        200));
    final client = AppUpdateClient(baseUrl: 'http://x', httpClient: mock);
    final info = await client.fetchVersionInfo();
    expect(info!.versionCode, 5);
    expect(info.versionName, '1.0.0+5');
  });

  test('fetchVersionInfo 404-də null qaytarır', () async {
    final mock = MockClient((req) async => http.Response('not found', 404));
    final client = AppUpdateClient(baseUrl: 'http://x', httpClient: mock);
    expect(await client.fetchVersionInfo(), isNull);
  });

  test('fetchVersionInfo xətada null qaytarır (atmır)', () async {
    final mock = MockClient((req) async => throw Exception('boom'));
    final client = AppUpdateClient(baseUrl: 'http://x', httpClient: mock);
    expect(await client.fetchVersionInfo(), isNull);
  });

  group('fetchVersionInfoDetailed (diaqnostika)', () {
    test('uğurda info qaytarır, xəta yoxdur', () async {
      final mock = MockClient((req) async => http.Response.bytes(
          utf8.encode(jsonEncode(
              {'version_code': 20, 'version_name': '1.0.0+20', 'notes': ''})),
          200));
      final r = await AppUpdateClient(baseUrl: 'http://x', httpClient: mock)
          .fetchVersionInfoDetailed();
      expect(r.info!.versionCode, 20);
      expect(r.error, isNull);
    });

    test('403-də SƏBƏBİ qaytarır (səssiz null yox)', () async {
      // Cloudflare bəzi User-Agent-ləri bloklayır — bu, canlıda baş verib.
      final mock = MockClient((req) async => http.Response('blocked', 403));
      final r = await AppUpdateClient(baseUrl: 'http://x', httpClient: mock)
          .fetchVersionInfoDetailed();
      expect(r.info, isNull);
      expect(r.error, contains('403'));
    });

    test('şəbəkə istisnasının səbəbi qaytarılır', () async {
      final mock = MockClient((req) async => throw Exception('SocketException'));
      final r = await AppUpdateClient(baseUrl: 'http://x', httpClient: mock)
          .fetchVersionInfoDetailed();
      expect(r.info, isNull);
      expect(r.error, contains('SocketException'));
    });

    test('xarab JSON-un səbəbi qaytarılır', () async {
      final mock = MockClient(
          (req) async => http.Response.bytes(utf8.encode('<html>'), 200));
      final r = await AppUpdateClient(baseUrl: 'http://x', httpClient: mock)
          .fetchVersionInfoDetailed();
      expect(r.info, isNull);
      expect(r.error, isNotNull);
    });

    test('fetchVersionInfo eyni məntiqə söykənir', () async {
      final mock = MockClient((req) async => http.Response('x', 500));
      expect(
        await AppUpdateClient(baseUrl: 'http://x', httpClient: mock)
            .fetchVersionInfo(),
        isNull,
      );
    });
  });

  test('downloadApk baytları fayla yazır və yolu qaytarır', () async {
    final mock = MockClient(
        (req) async => http.Response.bytes([1, 2, 3, 4], 200));
    final client = AppUpdateClient(baseUrl: 'http://x', httpClient: mock);
    final dir = await Directory.systemTemp.createTemp('dildostu_test_');
    final dest = '${dir.path}${Platform.pathSeparator}update.apk';
    final path = await client.downloadApk(dest);
    expect(path, dest);
    expect(await File(dest).readAsBytes(), [1, 2, 3, 4]);
    await dir.delete(recursive: true);
  });

  test('downloadApk böyük faylı hissə-hissə (axın) yazır', () async {
    // 20MB-lıq axın — real APK-nın kiçildilmiş modeli. Məqsəd: `send()` +
    // `stream.pipe` çoxlu çanaqdan gələn datanı düzgün ardıcıllıqla fayla
    // yazır (tək bufferə yığıb sonra yazan `get()...bodyBytes`-dan fərqli).
    final chunk = List.filled(1024 * 1024, 7); // 1MB chunk, 20 dəfə
    final fake = _StreamingFakeClient(
      List.generate(20, (_) => chunk),
      statusCode: 200,
    );
    final client = AppUpdateClient(baseUrl: 'http://x', httpClient: fake);
    final dir = await Directory.systemTemp.createTemp('dildostu_test_');
    final dest = '${dir.path}${Platform.pathSeparator}update.apk';
    final path = await client.downloadApk(dest);
    expect(path, dest);
    expect(await File(dest).length(), 20 * 1024 * 1024);
    await dir.delete(recursive: true);
  });

  test('downloadApk yükləmə gedişatını bildirir (onProgress)', () async {
    final chunk = List.filled(1000, 1);
    final fake = _StreamingFakeClient(
      List.generate(5, (_) => chunk),
      statusCode: 200,
    );
    final client = AppUpdateClient(baseUrl: 'http://x', httpClient: fake);
    final dir = await Directory.systemTemp.createTemp('dildostu_test_');
    final dest = '${dir.path}${Platform.pathSeparator}update.apk';

    final received = <int>[];
    int? reportedTotal;
    await client.downloadApk(dest, onProgress: (got, total) {
      received.add(got);
      reportedTotal = total;
    });

    // Hər çanaqdan sonra artan ölçü bildirilir (UI faizi buradan hesablayır).
    expect(received, [1000, 2000, 3000, 4000, 5000]);
    expect(reportedTotal, 5000);
    await dir.delete(recursive: true);
  });

  test('404 → null qaytarır, fayl yaranmır', () async {
    final mock = MockClient((req) async => http.Response('not found', 404));
    final client = AppUpdateClient(baseUrl: 'http://x', httpClient: mock);
    final dir = await Directory.systemTemp.createTemp('dildostu_test_');
    final dest = '${dir.path}${Platform.pathSeparator}update.apk';
    final path = await client.downloadApk(dest);
    expect(path, isNull);
    expect(await File(dest).exists(), isFalse);
    await dir.delete(recursive: true);
  });

  test('axın xətası → null qaytarır və yarımçıq faylı silir', () async {
    final mock = MockClient((req) async => throw Exception('network'));
    final client = AppUpdateClient(baseUrl: 'http://x', httpClient: mock);
    final dir = await Directory.systemTemp.createTemp('dildostu_test_');
    final dest = '${dir.path}${Platform.pathSeparator}update.apk';
    final path = await client.downloadApk(dest);
    expect(path, isNull);
    expect(await File(dest).exists(), isFalse);
    await dir.delete(recursive: true);
  });
}

/// `send()`-i birbaşa çoxçanaqlı `StreamedResponse` ilə cavablandıran saxta
/// client — `MockClient`-in `Response`-ə əsaslanan sadə interfeysi çoxçanaqlı
/// axını simulyasiya etmək üçün kifayət etmir.
class _StreamingFakeClient extends http.BaseClient {
  _StreamingFakeClient(this.chunks, {required this.statusCode});

  final List<List<int>> chunks;
  final int statusCode;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // `contentLength` real serverin `Content-Length` başlığını təqlid edir —
    // UI faizi bundan hesablanır (canlıda yoxlanılıb: 157808908 bayt).
    return http.StreamedResponse(
      Stream.fromIterable(chunks),
      statusCode,
      contentLength: chunks.fold<int>(0, (sum, c) => sum + c.length),
    );
  }
}
