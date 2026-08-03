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
