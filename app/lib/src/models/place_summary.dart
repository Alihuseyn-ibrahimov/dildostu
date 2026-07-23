/// Serverin `/routine/summary` cavabındakı bir məkan aqreqatı — "AI nəyi
/// öyrənib" ekranı üçün.
class PlaceSummary {
  const PlaceSummary({
    required this.placeType,
    required this.count,
    required this.lastSeen,
    this.packId,
  });

  final String placeType;
  final int count;
  final String lastSeen; // ISO 8601 UTC (serverdən)
  final String? packId;

  factory PlaceSummary.fromServerJson(Map<String, dynamic> json) {
    return PlaceSummary(
      placeType: json['place_type'] as String,
      count: json['count'] as int,
      lastSeen: json['last_seen'] as String,
      packId: json['pack_id'] as String?,
    );
  }
}
