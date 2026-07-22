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

/// Dil səviyyəsi (server ilə uzlaşan sətrlər).
enum ProficiencyLevel {
  beginner('beginner'),
  intermediate('intermediate');

  const ProficiencyLevel(this.wire);
  final String wire;

  static ProficiencyLevel fromWire(String s) =>
      ProficiencyLevel.values.firstWhere((e) => e.wire == s);
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
