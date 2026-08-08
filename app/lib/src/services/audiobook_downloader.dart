import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/audiobook.dart';

const _libraryCacheFileName = 'audiobooks_library_cache.json';

/// Səsli kitabları telefona endirib "bir dəfə yüklə, sonra offline dinlə"
/// prinsipini təmin edir (bax dildostu/CLAUDE.md — əsas fəlsəfə: səyahət
/// zamanı internet olmasa belə tətbiq işləməlidir).
///
/// Fayllar `<sənədlər>/audiobooks/<bookId>/<chapterId>.mp3`-də saxlanılır.
/// Yarımçıq yükləmə "tamamlanmış" sayılmasın deyə əvvəlcə `.part` müvəqqəti
/// fayla yazılır, uğurla bitəndə son ada ATOMİK köçürülür (`rename`) —
/// proses yarıda kəsilsə (məs. app bağlanıb) köhnə/yarımçıq fayl "yüklənib"
/// kimi görünmür, növbəti cəhddə yenidən endirilir.
///
/// `baseDirOverride` yalnız testlər üçündür — `path_provider` platform
/// kanalı olmadan (məs. unit testdə) yerli qovluğu təyin etməyə imkan verir.
class AudiobookDownloader extends ChangeNotifier {
  AudiobookDownloader({this._baseDirOverride});

  /// Yalnız testlər üçün — `path_provider` platform kanalı olmadan yerli
  /// qovluğu təyin etməyə imkan verir.
  final Directory? _baseDirOverride;
  Directory? _docsDir;
  Directory? _baseDir;
  final Set<String> _downloadedKeys = {};

  bool downloading = false;
  int downloadedBytesDone = 0;
  int totalBytesTarget = 0;
  int failedChapters = 0;
  int _lastNotifiedPercent = -1;

  double get progress =>
      totalBytesTarget > 0 ? downloadedBytesDone / totalBytesTarget : 0;

  static String _key(String bookId, String chapterId) => '$bookId/$chapterId';

  /// Yerli qovluğu hazırlayır və artıq endirilmiş fəsilləri diskdən oxuyub
  /// yaddaşda siyahıya alır. Xəta halında səssiz keçir — offline funksiya
  /// olmasa app-ın qalan hissəsi işləməyi dayandırmamalıdır.
  Future<void> init() async {
    try {
      _docsDir = _baseDirOverride ?? await getApplicationDocumentsDirectory();
      final dir = Directory('${_docsDir!.path}/audiobooks');
      if (!await dir.exists()) await dir.create(recursive: true);
      _baseDir = dir;
      await _scan();
    } catch (_) {
      // Bax yuxarıdaki izah — heç bir kitab "yüklənmiş" görünmür, axın kimi.
    }
  }

  Future<void> _scan() async {
    final dir = _baseDir;
    if (dir == null) return;
    _downloadedKeys.clear();
    try {
      await for (final bookEntry in dir.list()) {
        if (bookEntry is! Directory) continue;
        final bookId = bookEntry.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last;
        await for (final f in bookEntry.list()) {
          if (f is File && f.path.endsWith('.mp3')) {
            final chapterId = f.uri.pathSegments.last.replaceAll('.mp3', '');
            _downloadedKeys.add(_key(bookId, chapterId));
          }
        }
      }
    } catch (_) {}
  }

  bool isDownloaded(String bookId, String chapterId) =>
      _downloadedKeys.contains(_key(bookId, chapterId));

  bool isBookFullyDownloaded(Audiobook book) => book.chapters.isNotEmpty &&
      book.chapters.every((c) => isDownloaded(book.bookId, c.chapterId));

  /// Yerli fayl yolu (yüklənibsə); yoxdursa `null` — çağıran uzaq URL-ə düşür.
  String? localPath(String bookId, String chapterId) {
    if (!isDownloaded(bookId, chapterId)) return null;
    final dir = _baseDir;
    if (dir == null) return null;
    return '${dir.path}/$bookId/$chapterId.mp3';
  }

  /// Verilmiş kitablar üçün hələ endirilməmiş fəsillərin ümumi ölçüsü (bayt).
  int pendingBytes(List<Audiobook> books) {
    var total = 0;
    for (final b in books) {
      for (final c in b.chapters) {
        if (!isDownloaded(b.bookId, c.chapterId)) total += c.sizeBytes;
      }
    }
    return total;
  }

  /// Onsuz da diskdə olan fəsillərin ümumi ölçüsü (Ayarlarda "Yüklənib: X MB").
  int downloadedBytes(List<Audiobook> books) {
    var total = 0;
    for (final b in books) {
      for (final c in b.chapters) {
        if (isDownloaded(b.bookId, c.chapterId)) total += c.sizeBytes;
      }
    }
    return total;
  }

  /// Bütün kitabların yüklənməmiş fəsillərini fona endirir. Bir fəsil
  /// uğursuz olsa növbətiyə keçilir (bütün partiya ləğv olunmur) —
  /// `failedChapters` sayına görə çağıran istifadəçiyə bildirə bilər.
  /// Eyni anda ikinci çağırış səssiz keçir (`downloading` yoxlanır).
  Future<void> downloadAll(
    List<Audiobook> books, {
    required String Function(String bookId, String chapterId) urlFor,
    http.Client? httpClient,
  }) async {
    final dir = _baseDir;
    if (dir == null || downloading) return;
    final client = httpClient ?? http.Client();
    downloading = true;
    failedChapters = 0;
    totalBytesTarget = pendingBytes(books);
    downloadedBytesDone = 0;
    _lastNotifiedPercent = -1;
    notifyListeners();
    try {
      for (final book in books) {
        for (final chapter in book.chapters) {
          if (isDownloaded(book.bookId, chapter.chapterId)) continue;
          final ok = await _downloadChapter(
            client: client,
            bookId: book.bookId,
            chapterId: chapter.chapterId,
            url: urlFor(book.bookId, chapter.chapterId),
          );
          if (ok) {
            _downloadedKeys.add(_key(book.bookId, chapter.chapterId));
          } else {
            failedChapters++;
          }
          notifyListeners();
        }
      }
    } finally {
      downloading = false;
      notifyListeners();
    }
  }

  Future<bool> _downloadChapter({
    required http.Client client,
    required String bookId,
    required String chapterId,
    required String url,
  }) async {
    final dir = _baseDir;
    if (dir == null) return false;
    final bookDir = Directory('${dir.path}/$bookId');
    final partFile = File('${bookDir.path}/$chapterId.mp3.part');
    try {
      if (!await bookDir.exists()) await bookDir.create(recursive: true);
      final finalFile = File('${bookDir.path}/$chapterId.mp3');
      final request = http.Request('GET', Uri.parse(url));
      final streamed =
          await client.send(request).timeout(const Duration(minutes: 3));
      if (streamed.statusCode != 200) return false;
      final sink = partFile.openWrite();
      try {
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          downloadedBytesDone += chunk.length;
          if (totalBytesTarget > 0) {
            final percent = downloadedBytesDone * 100 ~/ totalBytesTarget;
            if (percent != _lastNotifiedPercent) {
              _lastNotifiedPercent = percent;
              notifyListeners();
            }
          } else {
            notifyListeners();
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      await partFile.rename(finalFile.path);
      return true;
    } catch (_) {
      try {
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
      return false;
    }
  }

  /// Kitabxana manifestinin xam JSON-unu yerli diskə saxlayır ki, növbəti
  /// açılışda server əlçatmaz olsa belə kitab siyahısı göstərilə bilsin.
  Future<void> cacheLibraryRaw(String rawJson) async {
    final dir = _docsDir;
    if (dir == null) return;
    try {
      await File('${dir.path}/$_libraryCacheFileName').writeAsString(rawJson);
    } catch (_) {}
  }

  Future<String?> cachedLibraryRaw() async {
    final dir = _docsDir;
    if (dir == null) return null;
    try {
      final f = File('${dir.path}/$_libraryCacheFileName');
      if (!await f.exists()) return null;
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Offline yaddaşı təmizləyir (Ayarlarda "Sil" düyməsi üçün).
  Future<void> clearDownloads() async {
    final dir = _baseDir;
    if (dir != null) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create(recursive: true);
        }
      } catch (_) {}
    }
    _downloadedKeys.clear();
    notifyListeners();
  }
}
