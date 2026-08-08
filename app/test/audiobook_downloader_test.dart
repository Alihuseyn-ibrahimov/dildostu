import 'dart:io';

import 'package:dildostu/src/models/audiobook.dart';
import 'package:dildostu/src/services/audiobook_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Audiobook _book({String id = 'aesop', int chapterCount = 2, int size = 1000}) =>
    Audiobook(
      bookId: id,
      titleEn: 'Title',
      titleAz: 'Başlıq',
      author: 'Author',
      source: 'Public domain',
      level: 'beginner',
      chapters: [
        for (var i = 0; i < chapterCount; i++)
          AudiobookChapter(
            chapterId: 'ch$i',
            titleEn: 'Chapter $i',
            duration: const Duration(seconds: 10),
            sizeBytes: size,
            text: 'Text $i',
          ),
      ],
    );

void main() {
  late Directory tempDir;
  late AudiobookDownloader downloader;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dildostu_ab_dl_');
    downloader = AudiobookDownloader(baseDirOverride: tempDir);
    await downloader.init();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('init boş qovluqda heç nəyi "yüklənmiş" saymır', () {
    expect(downloader.isDownloaded('aesop', 'ch0'), isFalse);
    expect(downloader.localPath('aesop', 'ch0'), isNull);
  });

  test('pendingBytes hələ endirilməyən fəsillərin ölçüsünü cəmləyir', () {
    final book = _book(chapterCount: 3, size: 500);
    expect(downloader.pendingBytes([book]), 1500);
  });

  group('downloadAll', () {
    test('fəsilləri yerli fayla yazır və "yüklənmiş" sayır', () async {
      final mock = MockClient(
          (req) async => http.Response.bytes(List.filled(1000, 7), 200));
      final book = _book(chapterCount: 2, size: 1000);
      await downloader.downloadAll(
        [book],
        urlFor: (b, c) => 'http://x/$b/$c.mp3',
        httpClient: mock,
      );
      expect(downloader.isDownloaded('aesop', 'ch0'), isTrue);
      expect(downloader.isDownloaded('aesop', 'ch1'), isTrue);
      final path = downloader.localPath('aesop', 'ch0');
      expect(path, isNotNull);
      expect(await File(path!).readAsBytes(), List.filled(1000, 7));
    });

    test('artıq endirilmiş fəsli təkrar yükləmir', () async {
      var requestCount = 0;
      final mock = MockClient((req) async {
        requestCount++;
        return http.Response.bytes(List.filled(10, 1), 200);
      });
      final book = _book(chapterCount: 1, size: 10);
      await downloader.downloadAll(
        [book],
        urlFor: (b, c) => 'http://x/$b/$c.mp3',
        httpClient: mock,
      );
      expect(requestCount, 1);
      // İkinci dəfə eyni kitabı endirmə cəhdi — artıq yüklənib, atlanmalıdır.
      await downloader.downloadAll(
        [book],
        urlFor: (b, c) => 'http://x/$b/$c.mp3',
        httpClient: mock,
      );
      expect(requestCount, 1);
    });

    test('bir fəsil uğursuz olsa qalanları yükləməyə davam edir', () async {
      final mock = MockClient((req) async {
        if (req.url.path.contains('ch0')) {
          throw Exception('network error');
        }
        return http.Response.bytes(List.filled(10, 1), 200);
      });
      final book = _book(chapterCount: 2, size: 10);
      await downloader.downloadAll(
        [book],
        urlFor: (b, c) => 'http://x/$b/$c.mp3',
        httpClient: mock,
      );
      expect(downloader.isDownloaded('aesop', 'ch0'), isFalse);
      expect(downloader.isDownloaded('aesop', 'ch1'), isTrue);
      expect(downloader.failedChapters, 1);
    });

    test('404 → fəsil yüklənməmiş qalır, yarımçıq fayl saxlanmır', () async {
      final mock = MockClient((req) async => http.Response('not found', 404));
      final book = _book(chapterCount: 1, size: 10);
      await downloader.downloadAll(
        [book],
        urlFor: (b, c) => 'http://x/$b/$c.mp3',
        httpClient: mock,
      );
      expect(downloader.isDownloaded('aesop', 'ch0'), isFalse);
      expect(downloader.failedChapters, 1);
      final partFile = File('${tempDir.path}/audiobooks/aesop/ch0.mp3.part');
      expect(await partFile.exists(), isFalse);
    });

    test('downloading bayrağı əməliyyat boyu düzgün idarə olunur', () async {
      final mock = MockClient(
          (req) async => http.Response.bytes(List.filled(10, 1), 200));
      expect(downloader.downloading, isFalse);
      final future = downloader.downloadAll(
        [_book(chapterCount: 1, size: 10)],
        urlFor: (b, c) => 'http://x/$b/$c.mp3',
        httpClient: mock,
      );
      await future;
      expect(downloader.downloading, isFalse);
    });
  });

  test('yenidən init edilən downloader diskdəki faylları tanıyır', () async {
    final mock = MockClient(
        (req) async => http.Response.bytes(List.filled(10, 1), 200));
    final book = _book(chapterCount: 1, size: 10);
    await downloader.downloadAll(
      [book],
      urlFor: (b, c) => 'http://x/$b/$c.mp3',
      httpClient: mock,
    );
    final fresh = AudiobookDownloader(baseDirOverride: tempDir);
    await fresh.init();
    expect(fresh.isDownloaded('aesop', 'ch0'), isTrue);
  });

  test('downloadedBytes yalnız diskdəki fəsilləri hesablayır', () async {
    final mock = MockClient(
        (req) async => http.Response.bytes(List.filled(100, 1), 200));
    final book = _book(chapterCount: 2, size: 100);
    await downloader.downloadAll(
      [book],
      urlFor: (b, c) => 'http://x/$b/$c.mp3',
      httpClient: mock,
    );
    expect(downloader.downloadedBytes([book]), 200);
    expect(downloader.pendingBytes([book]), 0);
    expect(downloader.isBookFullyDownloaded(book), isTrue);
  });

  test('clearDownloads bütün yerli faylları silir', () async {
    final mock = MockClient(
        (req) async => http.Response.bytes(List.filled(10, 1), 200));
    final book = _book(chapterCount: 1, size: 10);
    await downloader.downloadAll(
      [book],
      urlFor: (b, c) => 'http://x/$b/$c.mp3',
      httpClient: mock,
    );
    expect(downloader.isDownloaded('aesop', 'ch0'), isTrue);
    await downloader.clearDownloads();
    expect(downloader.isDownloaded('aesop', 'ch0'), isFalse);
    expect(downloader.localPath('aesop', 'ch0'), isNull);
  });

  group('kitabxana keşi', () {
    test('cacheLibraryRaw + cachedLibraryRaw eyni mətni saxlayır', () async {
      await downloader.cacheLibraryRaw('{"books": []}');
      expect(await downloader.cachedLibraryRaw(), '{"books": []}');
    });

    test('keş yoxdursa null qaytarır (xəta atmır)', () async {
      expect(await downloader.cachedLibraryRaw(), isNull);
    });
  });
}
