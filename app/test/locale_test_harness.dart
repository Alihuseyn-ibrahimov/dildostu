import 'package:dildostu/src/l10n/app_locale_scope.dart';
import 'package:dildostu/src/l10n/app_strings.dart';
import 'package:dildostu/src/l10n/material_app_l10n.dart';
import 'package:dildostu/src/models/ui_language.dart';
import 'package:flutter/material.dart';

/// Test widget-ləri üçün defolt AZ interfeys dili.
Widget wrapWithLocale(
  Widget child, {
  UiLanguage language = UiLanguage.az,
}) {
  return AppLocaleScope(
    language: language,
    strings: AppStrings(language),
    child: MaterialApp(
      localizationsDelegates: MaterialAppL10n.localizationsDelegates,
      supportedLocales: MaterialAppL10n.supportedLocales,
      locale: MaterialAppL10n.locale,
      home: child,
    ),
  );
}
