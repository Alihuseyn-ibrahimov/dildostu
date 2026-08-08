import '../models/pack.dart';
import '../models/audiobook.dart';
import '../models/song.dart';
import '../models/user_profile.dart';
import '../models/word.dart';

/// Statik paketdən seçilmiş səviyyəyə uyğun sözləri süzür (offline ehtiyat yolu;
/// onlayn halda məzmun AI-dan gəlir).
///
/// Spec §3 fallback qaydası: paketdə tam uyğun səviyyə yoxdursa ən yaxın
/// **aşağı** səviyyəyə düşür (Çətin → Orta → Asan). Aşağıda da yoxdursa yuxarı
/// baxır — boş ekran göstərməkdənsə yaxın çətinlikdə söz vermək yaxşıdır.
/// Bu lazımdır, çünki mövcud paketlərdə cəmi bir dənə level-3 söz var.
List<Word> wordsForLevel(Pack pack, ProficiencyLevel level) {
  if (pack.words.isEmpty) return const [];

  final target = level.wordLevel;
  // Əvvəl tam uyğunluq, sonra aşağı pillələr, sonra yuxarı pillələr.
  final order = <int>[
    target,
    for (var l = target - 1; l >= 1; l--) l,
    for (var l = target + 1; l <= 3; l++) l,
  ];

  for (final wanted in order) {
    final matches = pack.words.where((w) => w.level == wanted).toList();
    if (matches.isNotEmpty) return matches;
  }

  // Heç bir söz 1-3 aralığında deyil (xarab data) — hamısını qaytar.
  return pack.words;
}

/// Mahnı kataloqundan seçilmiş səviyyəyə uyğun mahnıları süzür.
///
/// `wordsForLevel` ilə eyni fallback qaydası: əvvəl tam uyğun səviyyə,
/// sonra aşağı pillələr, sonra yuxarı — boş siyahı göstərməkdənsə yaxın
/// səviyyədə mahnı vermək yaxşıdır.
List<Song> songsForLevel(List<Song> songs, ProficiencyLevel level) {
  if (songs.isEmpty) return const [];

  final order = <String>[
    level.wire,
    for (var l = level.wordLevel - 1; l >= 1; l--)
      ProficiencyLevel.values.firstWhere((p) => p.wordLevel == l).wire,
    for (var l = level.wordLevel + 1; l <= 3; l++)
      ProficiencyLevel.values.firstWhere((p) => p.wordLevel == l).wire,
  ];

  for (final wanted in order) {
    final matches = songs.where((s) => s.level == wanted).toList();
    if (matches.isNotEmpty) return matches;
  }

  return songs;
}

/// Səsli kitab kataloqundan YALNIZ seçilmiş səviyyəyə uyğun kitabları süzür.
///
/// Musiqi (`songsForLevel`) boş qalanda aşağı/yuxarı pilləyə düşür — səsli
/// kitablarda isə istifadəçi tələbi: asan səviyyədə çətin kitab görünməsin,
/// orta/çətin səviyyədə isə asan kitab gizlənsin. Fallback YOXDUR.
List<Audiobook> audiobooksForLevel(
  List<Audiobook> books,
  ProficiencyLevel level,
) {
  if (books.isEmpty) return const [];
  return books.where((b) => b.level == level.wire).toList();
}
