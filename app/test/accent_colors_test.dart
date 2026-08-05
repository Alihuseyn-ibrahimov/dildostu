import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _knownIds = [
  'airport', 'cafe', 'evening', 'greetings', 'hotel',
  'market', 'morning', 'pharmacy', 'restaurant', 'transport',
  'essential', 'audiobooks', 'music', 'chat',
];

void main() {
  test('hər id fərqli accent rəngi qaytarır', () {
    final colors = _knownIds.map((id) => accentFor(id).accent).toSet();
    expect(colors.length, _knownIds.length);
  });

  test('naməlum id essential ilə eynidir (heç vaxt sınmır)', () {
    expect(accentFor('naməlum_paket').accent, accentFor('essential').accent);
    expect(accentFor('').accent, accentFor('essential').accent);
  });

  test('tint həmişə accent-dən daha açıqdır', () {
    for (final id in _knownIds) {
      final c = accentFor(id);
      expect(c.tint.computeLuminance(), greaterThan(c.accent.computeLuminance()),
          reason: 'tint accent-dən açıq olmalıdır: $id');
    }
  });

  test('çox açıq baza rəngdə (morning) onAccent tündür', () {
    expect(accentFor('morning').onAccent, Colors.black87);
  });

  test('tünd baza rəngdə (airport) onAccent ağdır', () {
    expect(accentFor('airport').onAccent, Colors.white);
  });
}
