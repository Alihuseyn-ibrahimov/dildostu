import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../engine/lyrics_sync.dart';

final _wordPattern = lyricsWordPattern;

/// Mətni söz-söz "toxunula bilən" hissələrə bölür — hər söz üçün
/// `onTapWord` çağırılır. Durğu işarələri/boşluqlar toxunulmaz saxlanılır.
///
/// Səsli kitab oxuyucusunda naməlum sözə toxunub mənasına baxmaq üçün
/// işlədilir (bax `audiobook_player_screen.dart`).
List<InlineSpan> buildTappableWordSpans({
  required String text,
  required TextStyle? style,
  required void Function(String word) onTapWord,
}) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in _wordPattern.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start), style: style));
    }
    final word = match.group(0)!;
    spans.add(TextSpan(
      text: word,
      style: style,
      recognizer: TapGestureRecognizer()..onTap = () => onTapWord(word),
    ));
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: style));
  }
  return spans;
}

/// Sinxron vurğulama — hər sözün rəngi `styleForWord` ilə seçilir.
///
/// `wordIndex` yalnız hərfli sözlər üzrə artır (durğu/boşluq sayılmır).
List<InlineSpan> buildSyncedWordSpans({
  required String text,
  required TextStyle? baseStyle,
  required void Function(String word) onTapWord,
  required TextStyle? Function(int wordIndex) styleForWord,
}) {
  final spans = <InlineSpan>[];
  var last = 0;
  var wordIndex = 0;
  for (final match in _wordPattern.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(
        text: text.substring(last, match.start),
        style: baseStyle,
      ));
    }
    final word = match.group(0)!;
    spans.add(TextSpan(
      text: word,
      style: styleForWord(wordIndex) ?? baseStyle,
      recognizer: TapGestureRecognizer()..onTap = () => onTapWord(word),
    ));
    wordIndex++;
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: baseStyle));
  }
  return spans;
}
