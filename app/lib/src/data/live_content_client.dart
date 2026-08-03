import 'dart:convert';

import 'package:http/http.dart' as http;

import '../engine/level_content.dart';
import '../models/live_message.dart';
import '../models/user_profile.dart';
import '../models/word.dart';
import 'pack_repository.dart';

const _timeout = Duration(seconds: 5);

/// Canlı AI məzmununu serverdən alır; server/internet əlçatmaz olduqda
/// mövcud statik paketlərə (PackRepository) düşür (spec §4/§6).
///
/// `httpClient` inject olunur (mock ilə test); `fallbackRepo` offline mənbədir.
class LiveContentClient {
  LiveContentClient({
    required this.baseUrl,
    required this.fallbackRepo,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final PackRepository fallbackRepo;
  final http.Client _http;

  Future<LiveMessage> generate({
    required String packId,
    required int hour,
    required UserProfile profile,
    String? place,
    String mode = 'normal',
    List<String> recentWords = const [],
  }) async {
    try {
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/generate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'profile': profile.toServerJson(),
              'context': {'pack_id': packId, 'place': place, 'hour': hour},
              'recent_words': recentWords,
              'mode': mode,
            }),
          )
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        return LiveMessage.fromServerJson(
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>,
        );
      }
      return _fallback(packId, recentWords, profile.level);
    } catch (_) {
      return _fallback(packId, recentWords, profile.level);
    }
  }

  /// Paketin söz SİYAHISI (söz siyahısı ekranı üçün). Server əlçatmazsa statik
  /// paketin səviyyəyə uyğun sözlərinə düşür — ekran heç vaxt boş qalmır.
  Future<List<LiveMessage>> packWords({
    required String packId,
    required UserProfile profile,
    int count = 8,
  }) async {
    try {
      final resp = await _http
          .post(
            Uri.parse('$baseUrl/pack-words'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'profile': profile.toServerJson(),
              'pack_id': packId,
              'count': count,
            }),
          )
          // Siyahı generasiyası tək sözdən uzun çəkir.
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode == 200) {
        final body =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final raw = (body['words'] as List).cast<Map<String, dynamic>>();
        if (raw.isNotEmpty) {
          return [for (final w in raw) LiveMessage.fromServerJson(w)];
        }
      }
      return _fallbackList(packId, profile.level);
    } catch (_) {
      return _fallbackList(packId, profile.level);
    }
  }

  /// 504 sabit söz bankından (Əsas lüğət) növbəti dəst — səviyyəyə uyğun,
  /// `offset`-dən başlayaraq dövriyyəli (bank sonunda yenidən əvvələ qayıdır).
  ///
  /// Statik fallback YOXDUR (bu paketin tərcümə/nümunəsi yalnız AI ilə
  /// yaradılır) — server əlçatmaz olsa çağıran ekran xəta göstərib
  /// "Yenidən cəhd et" təklif edir.
  Future<
      ({
        List<LiveMessage> words,
        int total,
        int nextOffset,
      })> essentialWords({
    required UserProfile profile,
    int offset = 0,
    int count = 12,
  }) async {
    final resp = await _http
        .post(
          Uri.parse('$baseUrl/essential-words'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'profile': profile.toServerJson(),
            'offset': offset,
            'count': count,
          }),
        )
        // Siyahı generasiyası tək sözdən uzun çəkir.
        .timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw StateError('Əsas lüğət yüklənmədi (${resp.statusCode})');
    }
    final body =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final raw = (body['words'] as List).cast<Map<String, dynamic>>();
    return (
      words: [for (final w in raw) LiveMessage.fromServerJson(w)],
      total: body['total'] as int,
      nextOffset: body['next_offset'] as int,
    );
  }

  /// Offline siyahı — statik paketin səviyyəyə uyğun sözləri.
  List<LiveMessage> _fallbackList(String packId, ProficiencyLevel level) {
    final pack = fallbackRepo.byId(packId);
    if (pack == null) return const [];
    return [
      for (final w in wordsForLevel(pack, level))
        LiveMessage.fromWord(w, pack.packId),
    ];
  }

  /// Statik paketdən söz seç: əvvəlcə istifadəçinin səviyyəsinə uyğun sözlər
  /// süzülür (`wordsForLevel`, spec §3), sonra mümkünsə son sözlərdə olmayan
  /// seçilir. Paket yoxdursa ilk mövcud paket; heç bir söz yoxdursa StateError.
  LiveMessage _fallback(
      String packId, List<String> recentWords, ProficiencyLevel level) {
    final pack = fallbackRepo.byId(packId) ??
        (fallbackRepo.packs.isNotEmpty ? fallbackRepo.packs.first : null);
    if (pack == null || pack.words.isEmpty) {
      throw StateError('Fallback üçün statik paket yoxdur');
    }
    final candidates = wordsForLevel(pack, level);
    final Word word = candidates.firstWhere(
      (w) => !recentWords.contains(w.word),
      orElse: () => candidates.first,
    );
    return LiveMessage.fromWord(word, pack.packId);
  }
}
