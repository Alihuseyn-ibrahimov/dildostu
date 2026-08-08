import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// PopupMenuButton, TimePicker və s. Material widget-ləri üçün lokalizasiya.
///
/// Bizim interfeys mətnləri (`AppStrings`) ayrıdır — burada yalnız Flutter-in
/// daxili Material widget-ləri üçün `en` istifadə olunur (`az` dəstəklənmir).
const kMaterialAppLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const kMaterialAppSupportedLocales = [
  Locale('en'),
  Locale('ru'),
];

/// MaterialApp üçün standart lokalizasiya parametrləri.
class MaterialAppL10n {
  MaterialAppL10n._();

  static const localizationsDelegates = kMaterialAppLocalizationsDelegates;
  static const supportedLocales = kMaterialAppSupportedLocales;
  static const locale = Locale('en');
}
