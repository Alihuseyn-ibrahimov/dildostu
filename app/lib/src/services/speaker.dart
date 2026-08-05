import 'package:flutter_tts/flutter_tts.dart';

import '../data/tts_telemetry_repository.dart';

/// Səsləndirmə üçün nazik interfeys — UI bundan asılıdır, plugin-dən yox,
/// ona görə widget testlərində saxta (fake) speaker ötürmək olar.
abstract class Speaker {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> dispose();
}

/// Telefonun öz TTS mühərriki (offline, pulsuz). EN səsi quraşdırılmayıbsa
/// speak sakitcə uğursuz ola bilər — UI yazılı fallback göstərir.
///
/// [telemetry] verilibsə (Faza 0, ElevenLabs planı — baseline ölçüsü) hər
/// cəhd/uğursuzluq/əskik EN səsi sayılır ki, real uğursuzluq faizi bilinsin.
class TtsSpeaker implements Speaker {
  TtsSpeaker({
    FlutterTts? tts,
    this.language = 'en-US',
    TtsTelemetryRepository? telemetry,
  })  : _tts = tts ?? FlutterTts(),
        _telemetry = telemetry {
    _tts.setErrorHandler((msg) => _telemetry?.recordFailure());
  }

  final FlutterTts _tts;
  String language;
  TtsTelemetryRepository? _telemetry;
  bool _configured = false;

  /// Bootstrap zamanı repository asinxron yükləndiyi üçün sonradan bağlana
  /// bilir (konstruktor sinxron çağırılmalıdır ki, `dispose()` həmişə etibarlı
  /// obyektə işarə etsin).
  set telemetry(TtsTelemetryRepository? value) => _telemetry = value;

  /// Öyrənilən dil dəyişəndə (Ayarlardan) çağırılır — növbəti `speak()`
  /// yeni lokal koda (`TargetLanguage.ttsLocale`) keçir.
  set ttsLocale(String value) {
    if (language == value) return;
    language = value;
    _configured = false;
  }

  /// Ayarlar ekranında baseline rəqəmlərini göstərmək üçün cari anlıq şəkil.
  TtsTelemetry? get telemetrySnapshot => _telemetry?.current;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    final available = await _tts.isLanguageAvailable(language);
    if (available != true && available != 1) {
      await _telemetry?.recordNoVoiceDetected();
    }
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _configured = true;
  }

  @override
  Future<void> speak(String text) async {
    await _telemetry?.recordAttempt();
    try {
      await _ensureConfigured();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      await _telemetry?.recordFailure();
      rethrow;
    }
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() => _tts.stop();
}
