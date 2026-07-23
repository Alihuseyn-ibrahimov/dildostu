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
}
