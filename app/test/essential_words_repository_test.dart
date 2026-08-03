import 'dart:convert';

import 'package:dildostu/src/data/essential_words_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJsonString paketi düzgün parse edir', () {
    final json = jsonEncode({
      'pack_id': 'essential',
      'target_lang': 'en',
      'ui_lang': 'az',
      'title_az': 'Əsas lüğət',
      'words': [
        {
          'word': 'abandon',
          'translation_az': 'tərk etmək',
          'ipa': '/ə/',
          'example': 'x',
          'example_az': 'x',
          'level': 1,
        },
      ],
    });
    final repo = EssentialWordsRepository.fromJsonString(json);
    expect(repo.pack.packId, 'essential');
    expect(repo.pack.words, hasLength(1));
    expect(repo.pack.words.first.word, 'abandon');
  });

  test('xarab JSON FormatException atır', () {
    expect(
      () => EssentialWordsRepository.fromJsonString('not json'),
      throwsFormatException,
    );
  });
}
