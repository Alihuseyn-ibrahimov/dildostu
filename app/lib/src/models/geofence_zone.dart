/// Serverin `/routine/geofences` cavabındakı tez-tez gedilən yer.
class GeofenceZone {
  const GeofenceZone({
    required this.centerLat,
    required this.centerLng,
    required this.radius,
    required this.packId,
    required this.label,
  });

  final double centerLat;
  final double centerLng;
  final double radius; // metr
  final String packId;
  final String label;

  factory GeofenceZone.fromServerJson(Map<String, dynamic> json) {
    return GeofenceZone(
      centerLat: (json['center_lat'] as num).toDouble(),
      centerLng: (json['center_lng'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      packId: json['pack_id'] as String,
      label: json['label'] as String,
    );
  }

  /// Kooldown izləmə üçün sabit açar (server hər sorğuda klasterləri yenidən
  /// hesabladığı üçün mərkəz koordinatları bir qədər sürüşə bilər — 4 ondalıq
  /// dəqiqliyə (~11m) yuvarlaqlaşdırmaq açarı sabit saxlayır).
  String get stableKey =>
      '$packId:${centerLat.toStringAsFixed(4)}:${centerLng.toStringAsFixed(4)}';
}
