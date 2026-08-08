import 'package:flutter/material.dart';

import '../models/ui_language.dart';
import 'app_strings.dart';

/// Cari interfeys dili və tərcümələr — `context.s` ilə oxunur.
class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({
    super.key,
    required this.language,
    required this.strings,
    required super.child,
  });

  final UiLanguage language;
  final AppStrings strings;

  static AppLocaleScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'AppLocaleScope tapılmadı');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) =>
      language != oldWidget.language;
}

extension AppStringsContext on BuildContext {
  AppStrings get s => AppLocaleScope.of(this).strings;
}
