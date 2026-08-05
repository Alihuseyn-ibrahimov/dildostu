import 'package:dildostu/src/services/speaker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// `FlutterTts`-in çağırışlarını qeydə alan saxta versiya — platform
/// kanalına toxunmur (bütün istifadə olunan metodlar override olunub).
class _FakeFlutterTts extends FlutterTts {
  final List<String> setLanguageCalls = [];
  bool languageAvailable = true;

  @override
  Future<dynamic> setLanguage(String language) async {
    setLanguageCalls.add(language);
    return 1;
  }

  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      languageAvailable;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async => 1;

  @override
  Future<dynamic> stop() async => 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('speak() ilk çağırışda setLanguage-i tətbiq edir', () async {
    final fake = _FakeFlutterTts();
    final speaker = TtsSpeaker(tts: fake, language: 'en-US');

    await speaker.speak('hello');

    expect(fake.setLanguageCalls, ['en-US']);
  });

  test('eyni dil üçün ttsLocale setter təkrar setLanguage tətbiq etmir',
      () async {
    final fake = _FakeFlutterTts();
    final speaker = TtsSpeaker(tts: fake, language: 'en-US');
    await speaker.speak('hello');

    speaker.ttsLocale = 'en-US';
    await speaker.speak('hello again');

    expect(fake.setLanguageCalls, ['en-US']);
  });

  test('ttsLocale dəyişəndə növbəti speak() yeni dili tətbiq edir', () async {
    final fake = _FakeFlutterTts();
    final speaker = TtsSpeaker(tts: fake, language: 'en-US');
    await speaker.speak('hello');

    speaker.ttsLocale = 'ru-RU';
    await speaker.speak('privet');

    expect(fake.setLanguageCalls, ['en-US', 'ru-RU']);
  });
}
