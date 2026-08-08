/// Gündəlik söhbət kvotası — `GET /chat/quota` cavabı.
class ChatQuota {
  const ChatQuota({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  final int used;
  final int limit;
  final int remaining;

  factory ChatQuota.fromJson(Map<String, dynamic> json) => ChatQuota(
        used: json['used'] as int,
        limit: json['limit'] as int,
        remaining: json['remaining'] as int,
      );

  /// İstifadə olunmuş pay (0.0–1.0).
  double get fraction => limit > 0 ? used / limit : 0;

  /// Limitə yaxınlaşır (≤10 qalıb).
  bool get isLow => remaining <= 10;

  /// Bu gün üçün mesaj qalmayıb.
  bool get isExhausted => remaining <= 0;
}
