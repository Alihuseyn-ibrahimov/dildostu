import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

final _wordPattern = RegExp(r"[A-Za-z']+");

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
