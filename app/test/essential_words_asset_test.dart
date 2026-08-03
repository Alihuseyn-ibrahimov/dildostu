import 'package:dildostu/src/data/essential_words_repository.dart';
import 'package:dildostu/src/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bundle-a qoyulan HƏQİQİ `assets/essential/words.json`-un doğrulaması —
/// korlanmış/natamam fayl testdə tutulsun (offline "Əsas lüğət" bundan asılıdır).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assets/essential/words.json 504 söz, hər səviyyədə 168', () async {
    final repo = await EssentialWordsRepository.loadFromAssets();
    expect(repo.pack.packId, 'essential');
    expect(repo.pack.words, hasLength(504));

    for (final level in ProficiencyLevel.values) {
      final count =
          repo.pack.words.where((w) => w.level == level.wordLevel).length;
      expect(count, 168, reason: '${level.wire} üçün 168 söz gözlənilir');
    }
  });

  test('bütün sözlərin sahələri boş deyil', () async {
    final repo = await EssentialWordsRepository.loadFromAssets();
    for (final w in repo.pack.words) {
      expect(w.word, isNotEmpty);
      expect(w.translationAz, isNotEmpty);
      expect(w.ipa, isNotEmpty);
      expect(w.example, isNotEmpty);
      expect(w.exampleAz, isNotEmpty);
    }
  });

  test('sözlər arasında təkrar yoxdur', () async {
    final repo = await EssentialWordsRepository.loadFromAssets();
    final words = repo.pack.words.map((w) => w.word).toList();
    expect(words.toSet(), hasLength(words.length));
  });
}
