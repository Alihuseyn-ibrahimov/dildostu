import '../models/pack.dart';
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
