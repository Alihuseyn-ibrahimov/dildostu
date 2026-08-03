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
    return http.StreamedResponse(Stream.fromIterable(chunks), statusCode);
  }
}
