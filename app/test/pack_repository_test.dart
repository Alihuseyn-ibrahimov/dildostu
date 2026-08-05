import 'package:dildostu/src/data/pack_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `loadFromAssets`-i cihaz olmadan test etmək üçün — yalnız `loadString`-i
/// tələb olunan yollarla cavablandırır, qalanı "asset yoxdur" kimi atır.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.strings);
  final Map<String, String> strings;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final s = strings[key];
    if (s == null) throw Exception('asset tapılmadı: $key');
    return s;
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

String _packJson(String id, {int nWords = 2}) {
  final words = List.generate(
    nWords,
    (i) => '''
    {
      "word": "w_${id}_$i",
      "translation_az": "s_${id}_$i",
      "ipa": "/w$i/",
      "example": "Example $i.",
      "example_az": "Nümunə $i.",
      "level": 1
    }''',
  ).join(',');
  return '''
  {
    "pack_id": "$id",
    "target_lang": "en",
    "ui_lang": "az",
    "title_az": "Başlıq $id",
    "words": [$words]
  }''';
}

void main() {
  test('fromJsonStrings bütün paketləri parse edir', () {
    final repo = PackRepository.fromJsonStrings([
      _packJson('cafe'),
      _packJson('hotel', nWords: 3),
    ]);
    expect(repo.packs, hasLength(2));
    expect(repo.packIds, containsAll(['cafe', 'hotel']));
  });

  test('byId düzgün paketi qaytarır', () {
    final repo = PackRepository.fromJsonStrings([_packJson('cafe')]);
    expect(repo.byId('cafe')!.titleAz, 'Başlıq cafe');
    expect(repo.byId('yoxdur'), isNull);
  });

  test('paketlər pack_id-yə görə sıralanır (deterministik UI)', () {
    final repo = PackRepository.fromJsonStrings([
      _packJson('transport'),
      _packJson('airport'),
      _packJson('cafe'),
    ]);
    expect(repo.packs.map((p) => p.packId).toList(),
        ['airport', 'cafe', 'transport']);
  });

  test('xarab JSON aydın xəta atır', () {
    expect(
      () => PackRepository.fromJsonStrings(['{not valid']),
      throwsA(isA<FormatException>()),
    );
  });

  group('loadFromAssets', () {
    test('dilə görə düzgün qovluqdan yükləyir', () async {
      final bundle = _FakeBundle({
        'assets/packs/ru/cafe.json': _packJson('cafe'),
      });
      final repo = await PackRepository.loadFromAssets(
        lang: 'ru',
        bundle: bundle,
        ids: const ['cafe'],
      );
      expect(repo.byId('cafe'), isNotNull);
    });

    test('fayl hələ yoxdursa sınmır, boş qayıdır', () async {
      final bundle = _FakeBundle(const {});
      final repo = await PackRepository.loadFromAssets(
        lang: 'ru',
        bundle: bundle,
        ids: const ['cafe', 'hotel'],
      );
      expect(repo.packs, isEmpty);
    });

    test('bir dilin faylları başqa dilin qovluğundan yüklənmir', () async {
      final bundle = _FakeBundle({
        'assets/packs/en/cafe.json': _packJson('cafe'),
      });
      final repo = await PackRepository.loadFromAssets(
        lang: 'ru',
        bundle: bundle,
        ids: const ['cafe'],
      );
      expect(repo.packs, isEmpty);
    });
  });
}
