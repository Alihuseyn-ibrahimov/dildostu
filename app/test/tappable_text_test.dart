import 'package:dildostu/src/ui/tappable_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hər sözü ayrıca span kimi verir', () {
    final tapped = <String>[];
    final spans = buildTappableWordSpans(
      text: 'Hello world',
      style: null,
      onTapWord: tapped.add,
    );
    final texts = spans.map((s) => (s as TextSpan).text).toList();
    expect(texts, ['Hello', ' ', 'world']);
  });

  test('durğu işarələri ayrıca, toxunulmaz span kimi qalır', () {
    final spans = buildTappableWordSpans(
      text: 'Well, hello!',
      style: null,
      onTapWord: (_) {},
    );
    final texts = spans.map((s) => (s as TextSpan).text).toList();
    expect(texts, ['Well', ', ', 'hello', '!']);
    // Durğu span-larının recognizer-i yoxdur.
    expect((spans[1] as TextSpan).recognizer, isNull);
    expect((spans[3] as TextSpan).recognizer, isNull);
  });

  test('söz span-larının TapGestureRecognizer-i var və toxunanda çağırır',
      () {
    final tapped = <String>[];
    final spans = buildTappableWordSpans(
      text: 'one two',
      style: null,
      onTapWord: tapped.add,
    );
    final oneSpan = spans[0] as TextSpan;
    final recognizer = oneSpan.recognizer as TapGestureRecognizer;
    recognizer.onTap!();
    expect(tapped, ['one']);
  });

  test('boş mətn boş siyahı qaytarır', () {
    expect(buildTappableWordSpans(text: '', style: null, onTapWord: (_) {}),
        isEmpty);
  });

  test('yalnız durğu/boşluqdan ibarət mətndə söz span-ı olmur', () {
    final spans = buildTappableWordSpans(
      text: '... !!!',
      style: null,
      onTapWord: (_) {},
    );
    for (final s in spans) {
      expect((s as TextSpan).recognizer, isNull);
    }
  });

  test('apostroflu sözlər (İngilis) bir span kimi qalır', () {
    final spans = buildTappableWordSpans(
      text: "don't stop",
      style: null,
      onTapWord: (_) {},
    );
    expect((spans.first as TextSpan).text, "don't");
  });
}
