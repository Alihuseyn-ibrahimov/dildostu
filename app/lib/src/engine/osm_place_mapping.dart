/// OpenStreetMap Overpass tag-larını DilDostu paket kateqoriyasına çevirir.
/// Uyğun kateqoriya tapılmasa `null` qaytarır (ContextEngine bu halda
/// vaxt qaydasına düşür).
String? packIdForOsmTags(Map<String, String> tags) {
  const amenityMap = {
    'cafe': 'cafe',
    'restaurant': 'restaurant',
    'fast_food': 'restaurant',
    'food_court': 'restaurant',
    'pharmacy': 'pharmacy',
    'marketplace': 'market',
  };
  const shopMap = {
    'supermarket': 'market',
    'convenience': 'market',
    'grocery': 'market',
    'mall': 'market',
    'department_store': 'market',
    'general': 'market',
    'wholesale': 'market',
  };
  const aerowayMap = {
    'aerodrome': 'airport',
    'terminal': 'airport',
  };
  const tourismMap = {
    'hotel': 'hotel',
    'guest_house': 'hotel',
    'hostel': 'hotel',
  };

  final amenity = tags['amenity'];
  if (amenity != null && amenityMap.containsKey(amenity)) {
    return amenityMap[amenity];
  }
  final shop = tags['shop'];
  if (shop != null) {
    // Bilinən mağaza növləri; digər hər hansı `shop=*` (geyim, elektronika...)
    // ümumi alış-veriş kimi market paketinə düşür.
    return shopMap[shop] ?? 'market';
  }
  final aeroway = tags['aeroway'];
  if (aeroway != null && aerowayMap.containsKey(aeroway)) {
    return aerowayMap[aeroway];
  }
  final tourism = tags['tourism'];
  if (tourism != null && tourismMap.containsKey(tourism)) {
    return tourismMap[tourism];
  }
  if (tags.containsKey('public_transport') ||
      tags.containsKey('railway') ||
      tags['highway'] == 'bus_stop') {
    return 'transport';
  }
  return null;
}
