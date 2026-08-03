/// İstifadəçinin niyə dil öyrəndiyi (server ilə uzlaşan sətrlər).
enum LearningPurpose {
  travel('travel'),
  work('work'),
  general('general');

  const LearningPurpose(this.wire);
  final String wire;

  static LearningPurpose fromWire(String s) =>
      LearningPurpose.values.firstWhere((e) => e.wire == s);
}

/// Çətinlik səviyyəsi — həm onboarding seçimi, həm ana səhifədəki filtr, həm də
/// serverə gedən `profile.level` dəyəri (spec §1: tək mənbə).
///
/// Wire dəyərləri serverin `Level` literal-ı ilə uzlaşır. `advanced`
/// 2026-08-03-də əlavə edildi; ilk iki dəyər dəyişmədiyi üçün cihazda
/// saxlanmış köhnə profillər sınmır.
enum ProficiencyLevel {
  beginner('beginner', 'Asan', 1, 'Ən çox işlənən sözlər, qısa cümlələr'),
  intermediate('intermediate', 'Orta', 2, 'İfadələr, keçmiş və gələcək zaman'),
  advanced('advanced', 'Çətin', 3, 'İdiomlar, uzun və mürəkkəb cümlələr');

  const ProficiencyLevel(this.wire, this.labelAz, this.wordLevel, this.hintAz);

  final String wire;

  /// UI-da göstərilən Azərbaycanca ad.
  final String labelAz;

  /// Seçicinin altında görünən qısa izah (spec §2 cədvəlinin xülasəsi).
  final String hintAz;

  /// `Word.level` / `LiveMessage.level` sahəsindəki qarşılığı (1-3).
  final int wordLevel;

  /// Naməlum dəyər gəlsə (köhnə/xarab profil) orta səviyyəyə düşür — app
  /// açılışda sınmamalıdır.
  static ProficiencyLevel fromWire(String s) => ProficiencyLevel.values
      .firstWhere((e) => e.wire == s, orElse: () => ProficiencyLevel.intermediate);
}

/// Onboarding-də toplanan istifadəçi profili. Canlı AI mesajlarını
/// fərdiləşdirmək üçün serverə göndərilir (`toServerJson`).
class UserProfile {
  const UserProfile({
    required this.wakeHour,
    required this.sleepHour,
    required this.purpose,
    required this.level,
    required this.interests,
  });

  final int wakeHour;
  final int sleepHour;
  final LearningPurpose purpose;
  final ProficiencyLevel level;
  final List<String> interests;

  /// Səviyyə dəyişəndə (ana səhifədəki filtr) yeni profil qurmaq üçün.
  UserProfile copyWith({ProficiencyLevel? level}) => UserProfile(
        wakeHour: wakeHour,
        sleepHour: sleepHour,
        purpose: purpose,
        level: level ?? this.level,
        interests: interests,
      );

  Map<String, dynamic> toJson() => {
        'wake_hour': wakeHour,
        'sleep_hour': sleepHour,
        'purpose': purpose.wire,
        'level': level.wire,
        'interests': interests,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        wakeHour: json['wake_hour'] as int,
        sleepHour: json['sleep_hour'] as int,
        purpose: LearningPurpose.fromWire(json['purpose'] as String),
        level: ProficiencyLevel.fromWire(json['level'] as String),
        interests: (json['interests'] as List<dynamic>).cast<String>(),
      );

  /// Serverin gözlədiyi format (toJson ilə eynidir, amma açıq niyyət üçün ayrı).
  Map<String, dynamic> toServerJson() => toJson();
}
