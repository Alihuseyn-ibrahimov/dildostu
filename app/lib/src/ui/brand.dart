import 'package:flutter/material.dart';

/// LachinGo vizual identifikasiya tokenləri.
///
/// Rəqib analizi (Duolingo, Babbel, Memrise):
/// - tam ekran brend gradienti (ağ boş ekran yox);
/// - mərkəzdə sadə ikon + wordmark (splash-da mətn yığını yox);
/// - bir əsas + bir vurğu rəngi (göy səma + qızıl quş);
/// - yükləmədə incə progress göstəricisi.
class BrandColors {
  const BrandColors._();

  /// Əsas brend — göy səma / səyahət.
  static const navy = Color(0xFF1B4F8A);

  /// Quş / enerji vurğusu.
  static const gold = Color(0xFFF5A623);

  /// Splash və bootstrap fonu.
  static const skyTop = Color(0xFFD4E8F8);
  static const skyMid = Color(0xFFEDF5FC);
  static const skyBottom = Color(0xFFF8FBFF);

  static const splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyMid, skyBottom, Colors.white],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const loginHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B4F8A), Color(0xFF2A6CB8), Color(0xFF4A90D9)],
  );
}

/// Brend tagline — giriş və yükləmə ekranlarında.
const kBrandTagline = 'Səyahət yoldaşın';
