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

/// Öyrənilən dil — həm onboarding seçimi, həm Ayarlardan dəyişiklik, həm də
/// serverə gedən `profile.target_lang` dəyəri (bax spec:
/// 2026-08-04-multilanguage-russian-design.md). Wire dəyərləri serverin
/// `TargetLanguage` literal-ı ilə uzlaşır.
enum TargetLanguage {
  english('en', 'İngilis', 'English', 'en-US'),
  russian('ru', 'Rus', 'Русский', 'ru-RU'),
  spanish('es', 'İspan', 'Español', 'es-ES'),
  italian('it', 'İtalyan', 'Italiano', 'it-IT');

  const TargetLanguage(this.wire, this.labelAz, this.nativeLabel, this.ttsLocale);

  final String wire;

  /// Ayarlar/izah üçün Azərbaycanca ad (UI seçicilərində işlədilmir).
  final String labelAz;

  /// UI-da göstərilən ad — həmin dilin öz yazılışı (English, Español, …).
  final String nativeLabel;

  /// `flutter_tts`-in `setLanguage` çağırışına ötürülən lokal kod.
  final String ttsLocale;

  /// UI-da dil adının solunda göstərilən bayraq (emoji).
  String get flagEmoji => switch (this) {
        TargetLanguage.english => '🇬🇧',
        TargetLanguage.russian => '🇷🇺',
        TargetLanguage.spanish => '🇪🇸',
        TargetLanguage.italian => '🇮🇹',
      };

  /// Naməlum/köhnə dəyər gəlsə (sahə heç olmayan köhnə profil) İngilisə
  /// düşür — app açılışda sınmamalıdır.
  static TargetLanguage fromWire(String s) => TargetLanguage.values
      .firstWhere((e) => e.wire == s, orElse: () => TargetLanguage.english);
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
    this.targetLang = TargetLanguage.english,
  });

  final int wakeHour;
  final int sleepHour;
  final LearningPurpose purpose;
  final ProficiencyLevel level;
  final List<String> interests;
  final TargetLanguage targetLang;

  /// Səviyyə/dil dəyişəndə (ana səhifə/ayarlar filtri) yeni profil qurmaq üçün.
  UserProfile copyWith({ProficiencyLevel? level, TargetLanguage? targetLang}) =>
      UserProfile(
        wakeHour: wakeHour,
        sleepHour: sleepHour,
        purpose: purpose,
        level: level ?? this.level,
        interests: interests,
        targetLang: targetLang ?? this.targetLang,
      );

  Map<String, dynamic> toJson() => {
        'wake_hour': wakeHour,
        'sleep_hour': sleepHour,
        'purpose': purpose.wire,
        'level': level.wire,
        'interests': interests,
        'target_lang': targetLang.wire,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        wakeHour: json['wake_hour'] as int,
        sleepHour: json['sleep_hour'] as int,
        purpose: LearningPurpose.fromWire(json['purpose'] as String),
        level: ProficiencyLevel.fromWire(json['level'] as String),
        interests: (json['interests'] as List<dynamic>).cast<String>(),
        // Köhnə saxlanmış profil bloklarında bu sahə yoxdur — defolt İngilis.
        targetLang: TargetLanguage.fromWire(
            json['target_lang'] as String? ?? TargetLanguage.english.wire),
      );

  /// Serverin gözlədiyi format (toJson ilə eynidir, amma açıq niyyət üçün ayrı).
  Map<String, dynamic> toServerJson() => toJson();
}
