import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// Dil adı + sol bayraq — bütün seçicilərdə eyni görünüş.
class LanguageLabel extends StatelessWidget {
  const LanguageLabel(
    this.language, {
    super.key,
    this.style,
    this.flagSize = 18,
    this.gap = 6,
    this.textColor,
  });

  final TargetLanguage language;
  final TextStyle? style;
  final double flagSize;
  final double gap;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = style ??
        theme.textTheme.labelLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(language.flagEmoji, style: TextStyle(fontSize: flagSize, height: 1)),
        SizedBox(width: gap),
        Text(language.nativeLabel, style: textStyle),
      ],
    );
  }
}
