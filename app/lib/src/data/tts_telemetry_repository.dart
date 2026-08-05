import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'dildostu.tts_telemetry.v1';

/// Baseline ölçüsü (Faza 0, ElevenLabs planı): `flutter_tts`-in cihazda
/// nə qədər tez-tez səssizcə uğursuz olduğunu ölçür — [CLAUDE.md]-də
/// sənədləşmiş şübhə rəqəmə çevrilir. Yalnız say saxlanır, mətn/audio yox.
class TtsTelemetry {
  const TtsTelemetry({
    required this.attempts,
    required this.failures,
    required this.noVoiceDetections,
    required this.since,
  });

  final int attempts;
  final int failures;
  final int noVoiceDetections;
  final DateTime since;

  double get failureRate => attempts == 0 ? 0 : failures / attempts;

  Map<String, dynamic> toJson() => {
        'attempts': attempts,
        'failures': failures,
        'noVoiceDetections': noVoiceDetections,
        'since': since.toIso8601String(),
      };

  static TtsTelemetry fromJson(Map<String, dynamic> json) => TtsTelemetry(
        attempts: json['attempts'] as int,
        failures: json['failures'] as int,
        noVoiceDetections: json['noVoiceDetections'] as int,
        since: DateTime.parse(json['since'] as String),
      );

  static TtsTelemetry empty() => TtsTelemetry(
        attempts: 0,
        failures: 0,
        noVoiceDetections: 0,
        since: DateTime.now(),
      );
}

/// `TtsTelemetry`-ni cihazda saxlayır (shared_preferences, JSON blob).
class TtsTelemetryRepository {
  TtsTelemetryRepository._(this._prefs, this.current);

  final SharedPreferences _prefs;
  TtsTelemetry current;

  static Future<TtsTelemetryRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final telemetry = raw == null
        ? TtsTelemetry.empty()
        : TtsTelemetry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return TtsTelemetryRepository._(prefs, telemetry);
  }

  Future<void> recordAttempt() => _update(
        TtsTelemetry(
          attempts: current.attempts + 1,
          failures: current.failures,
          noVoiceDetections: current.noVoiceDetections,
          since: current.since,
        ),
      );

  Future<void> recordFailure() => _update(
        TtsTelemetry(
          attempts: current.attempts,
          failures: current.failures + 1,
          noVoiceDetections: current.noVoiceDetections,
          since: current.since,
        ),
      );

  Future<void> recordNoVoiceDetected() => _update(
        TtsTelemetry(
          attempts: current.attempts,
          failures: current.failures,
          noVoiceDetections: current.noVoiceDetections + 1,
          since: current.since,
        ),
      );

  Future<void> _update(TtsTelemetry next) async {
    current = next;
    await _prefs.setString(_prefsKey, jsonEncode(next.toJson()));
  }
}
