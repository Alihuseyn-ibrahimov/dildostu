import 'package:flutter/material.dart';

/// Paket/xüsusiyyət üçün tək baza rəngdən avtomatik hesablanan palitra —
/// bax `docs/superpowers/specs/2026-08-04-colorful-pack-accents-design.md`.
///
/// Yalnız bir "accent" seçilir; yumşaq fon (`tint`) və accent üzərində
/// oxunaqlı mətn (`onAccent`) avtomatik törənir ki, bütün palitra eyni
/// vizual nisbətlə ("premium" yumşaqlıq) ardıcıl qalsın.
class AccentColor {
  const AccentColor._(this.accent, this.tint, this.onAccent);

  final Color accent;
  final Color tint;
  final Color onAccent;

  factory AccentColor.fromBase(Color base) {
    final tint = Color.lerp(base, Colors.white, 0.88)!;
    final onAccent =
        base.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return AccentColor._(base, tint, onAccent);
  }
}

const _baseColors = <String, Color>{
  'airport': Color(0xFF1E88E5),
  'cafe': Color(0xFF6D4C41),
  'evening': Color(0xFF5E35B1),
  'greetings': Color(0xFFD81B60),
  'hotel': Color(0xFFFF8F00),
  'market': Color(0xFF43A047),
  'morning': Color(0xFFFBC02D),
  'pharmacy': Color(0xFF00ACC1),
  'restaurant': Color(0xFFE53935),
  'transport': Color(0xFF546E7A),
  'essential': Color(0xFF0E7C66),
  'audiobooks': Color(0xFF7B1FA2),
  'music': Color(0xFFC2185B),
  'chat': Color(0xFF3949AB),
};

/// Paket id-si (və ya `essential`/`audiobooks`/`chat`) → aksent palitrası.
/// Naməlum id (gələcəkdə yeni paket) → brend tealə (`essential`) düşür,
/// heç vaxt sınmır.
AccentColor accentFor(String id) =>
    AccentColor.fromBase(_baseColors[id] ?? _baseColors['essential']!);
