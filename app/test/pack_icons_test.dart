import 'package:dildostu/src/ui/pack_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bilinən paketlər üçün spesifik ikon', () {
    expect(packIcon('cafe'), Icons.local_cafe);
    expect(packIcon('market'), Icons.shopping_cart);
    expect(packIcon('airport'), Icons.flight);
    expect(packIcon('restaurant'), Icons.restaurant);
  });

  test('naməlum paket → fallback (translate)', () {
    expect(packIcon('naməlum_paket'), Icons.translate);
    expect(packIcon(''), Icons.translate);
  });

  test('bütün mövcud paketlər fallback-dan fərqli ikon alır', () {
    const known = [
      'airport', 'cafe', 'evening', 'greetings', 'hotel',
      'market', 'morning', 'pharmacy', 'restaurant', 'transport',
    ];
    for (final id in known) {
      expect(packIcon(id), isNot(Icons.translate), reason: 'ikon yoxdur: $id');
    }
  });
}
