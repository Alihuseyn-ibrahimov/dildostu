import 'package:flutter/material.dart';

/// Proqram interfeysinin dili (öyrənilən dildən ayrı).
enum UiLanguage {
  az('az', 'Azərbaycan dili'),
  en('en', 'English'),
  ru('ru', 'Русский');

  const UiLanguage(this.wire, this.nativeLabel);

  final String wire;
  final String nativeLabel;

  Locale get locale => Locale(wire);

  static List<Locale> get supportedLocales =>
      UiLanguage.values.map((e) => e.locale).toList();

  static UiLanguage fromWire(String? wire) => UiLanguage.values.firstWhere(
        (e) => e.wire == wire,
        orElse: () => UiLanguage.az,
      );
}
