import 'package:flutter_tts/flutter_tts.dart';

/// Səsləndirmə üçün nazik interfeys — UI bundan asılıdır, plugin-dən yox,
/// ona görə widget testlərində saxta (fake) speaker ötürmək olar.
abstract class Speaker {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> dispose();
}

/// Telefonun öz TTS mühərriki (offline, pulsuz). EN səsi quraşdırılmayıbsa
/// speak sakitcə uğursuz ola bilər — UI yazılı fallback göstərir.
class TtsSpeaker implements Speaker {
  TtsSpeaker({FlutterTts? tts, this.language = 'en-US'})
      : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final String language;
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _configured = true;
  }

  @override
  Future<void> speak(String text) async {
    await _ensureConfigured();
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() => _tts.stop();
}
