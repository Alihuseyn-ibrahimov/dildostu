import 'ui_language.dart';

/// İstifadəçinin gün rejimi tənzimləri — oyanma/yatma vaxtı və gündəlik
/// bildiriş sayı (spec §3.2 ContextEngine/NotificationScheduler üçün).
class Settings {
  const Settings({
    required this.wakeHour,
    required this.wakeMinute,
    required this.sleepHour,
    required this.sleepMinute,
    required this.dailyNotificationCount,
    this.uiLanguage = UiLanguage.az,
  });

  final int wakeHour;
  final int wakeMinute;
  final int sleepHour;
  final int sleepMinute;
  final int dailyNotificationCount;

  /// Proqram interfeysinin dili (menyu, düymələr) — öyrənilən dildən ayrı.
  final UiLanguage uiLanguage;

  static const Settings defaults = Settings(
    wakeHour: 8,
    wakeMinute: 0,
    sleepHour: 22,
    sleepMinute: 0,
    dailyNotificationCount: 7,
  );

  Settings copyWith({
    int? wakeHour,
    int? wakeMinute,
    int? sleepHour,
    int? sleepMinute,
    int? dailyNotificationCount,
    UiLanguage? uiLanguage,
  }) =>
      Settings(
        wakeHour: wakeHour ?? this.wakeHour,
        wakeMinute: wakeMinute ?? this.wakeMinute,
        sleepHour: sleepHour ?? this.sleepHour,
        sleepMinute: sleepMinute ?? this.sleepMinute,
        dailyNotificationCount:
            dailyNotificationCount ?? this.dailyNotificationCount,
        uiLanguage: uiLanguage ?? this.uiLanguage,
      );

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        wakeHour: json['wake_hour'] as int,
        wakeMinute: json['wake_minute'] as int,
        sleepHour: json['sleep_hour'] as int,
        sleepMinute: json['sleep_minute'] as int,
        dailyNotificationCount: json['daily_notification_count'] as int,
        uiLanguage: UiLanguage.fromWire(json['ui_language'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'wake_hour': wakeHour,
        'wake_minute': wakeMinute,
        'sleep_hour': sleepHour,
        'sleep_minute': sleepMinute,
        'daily_notification_count': dailyNotificationCount,
        'ui_language': uiLanguage.wire,
      };
}
