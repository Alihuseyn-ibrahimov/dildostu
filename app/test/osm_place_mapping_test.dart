import 'package:dildostu/src/engine/osm_place_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amenity=cafe → cafe paketi', () {
    expect(packIdForOsmTags({'amenity': 'cafe'}), 'cafe');
  });

  test('amenity=restaurant / fast_food → restaurant paketi', () {
    expect(packIdForOsmTags({'amenity': 'restaurant'}), 'restaurant');
    expect(packIdForOsmTags({'amenity': 'fast_food'}), 'restaurant');
  });

  test('shop=supermarket/convenience → market paketi', () {
    expect(packIdForOsmTags({'shop': 'supermarket'}), 'market');
    expect(packIdForOsmTags({'shop': 'convenience'}), 'market');
  });

  test('ticarət mərkəzi / mağaza növləri → market paketi', () {
    expect(packIdForOsmTags({'shop': 'mall'}), 'market');
    expect(packIdForOsmTags({'shop': 'department_store'}), 'market');
    expect(packIdForOsmTags({'amenity': 'marketplace'}), 'market');
    // İxtiyari mağaza növü də ümumi alış-veriş kimi market-ə düşür
    expect(packIdForOsmTags({'shop': 'clothes'}), 'market');
    expect(packIdForOsmTags({'shop': 'electronics'}), 'market');
  });

  test('aeroway=aerodrome/terminal → airport paketi', () {
    expect(packIdForOsmTags({'aeroway': 'aerodrome'}), 'airport');
    expect(packIdForOsmTags({'aeroway': 'terminal'}), 'airport');
  });

  test('tourism=hotel → hotel paketi', () {
    expect(packIdForOsmTags({'tourism': 'hotel'}), 'hotel');
  });

  test('amenity=pharmacy → pharmacy paketi', () {
    expect(packIdForOsmTags({'amenity': 'pharmacy'}), 'pharmacy');
  });

  test('public_transport/highway=bus_stop → transport paketi', () {
    expect(packIdForOsmTags({'public_transport': 'station'}), 'transport');
    expect(packIdForOsmTags({'highway': 'bus_stop'}), 'transport');
    expect(packIdForOsmTags({'railway': 'station'}), 'transport');
  });

  test('naməlum tag-lər üçün null qaytarır', () {
    expect(packIdForOsmTags({'leisure': 'park'}), isNull);
    expect(packIdForOsmTags({}), isNull);
  });
}
