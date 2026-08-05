import 'package:dildostu/src/data/user_profile_repository.dart';
import 'package:dildostu/src/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserProfile model', () {
    test('toJson/fromJson round-trip', () {
      const p = UserProfile(
        wakeHour: 7,
        sleepHour: 23,
        purpose: LearningPurpose.travel,
        level: ProficiencyLevel.beginner,
        interests: ['yemək', 'idman'],
      );
      final restored = UserProfile.fromJson(p.toJson());
      expect(restored.purpose, LearningPurpose.travel);
      expect(restored.level, ProficiencyLevel.beginner);
      expect(restored.interests, ['yemək', 'idman']);
      expect(restored.wakeHour, 7);
    });

    test('serverJson enum-ları server sətrləri kimi verir', () {
      const p = UserProfile(
        wakeHour: 8,
        sleepHour: 22,
        purpose: LearningPurpose.work,
        level: ProficiencyLevel.intermediate,
        interests: [],
      );
      final j = p.toServerJson();
      expect(j['purpose'], 'work');
      expect(j['level'], 'intermediate');
      expect(j['wake_hour'], 8);
    });

    test('targetLang defolt İngilisdir', () {
      const p = UserProfile(
        wakeHour: 8,
        sleepHour: 22,
        purpose: LearningPurpose.work,
        level: ProficiencyLevel.intermediate,
        interests: [],
      );
      expect(p.targetLang, TargetLanguage.english);
      expect(p.toServerJson()['target_lang'], 'en');
    });

    test('targetLang round-trip', () {
      const p = UserProfile(
        wakeHour: 8,
        sleepHour: 22,
        purpose: LearningPurpose.work,
        level: ProficiencyLevel.intermediate,
        interests: [],
        targetLang: TargetLanguage.russian,
      );
      final restored = UserProfile.fromJson(p.toJson());
      expect(restored.targetLang, TargetLanguage.russian);
    });

    test('target_lang sahəsi olmayan köhnə JSON İngilisə düşür', () {
      final json = {
        'wake_hour': 8,
        'sleep_hour': 22,
        'purpose': 'work',
        'level': 'intermediate',
        'interests': <String>[],
      };
      final restored = UserProfile.fromJson(json);
      expect(restored.targetLang, TargetLanguage.english);
    });

    test('copyWith targetLang dəyişir, digər sahələr qalır', () {
      const p = UserProfile(
        wakeHour: 8,
        sleepHour: 22,
        purpose: LearningPurpose.work,
        level: ProficiencyLevel.intermediate,
        interests: ['musiqi'],
      );
      final updated = p.copyWith(targetLang: TargetLanguage.spanish);
      expect(updated.targetLang, TargetLanguage.spanish);
      expect(updated.level, ProficiencyLevel.intermediate);
      expect(updated.interests, ['musiqi']);
    });
  });

  group('TargetLanguage', () {
    test('fromWire 4 dəyəri tanıyır', () {
      expect(TargetLanguage.fromWire('en'), TargetLanguage.english);
      expect(TargetLanguage.fromWire('ru'), TargetLanguage.russian);
      expect(TargetLanguage.fromWire('es'), TargetLanguage.spanish);
      expect(TargetLanguage.fromWire('it'), TargetLanguage.italian);
    });

    test('naməlum dəyər İngilisə düşür', () {
      expect(TargetLanguage.fromWire('fr'), TargetLanguage.english);
      expect(TargetLanguage.fromWire(''), TargetLanguage.english);
    });

    test('ttsLocale hər dil üçün doğrudur', () {
      expect(TargetLanguage.english.ttsLocale, 'en-US');
      expect(TargetLanguage.russian.ttsLocale, 'ru-RU');
      expect(TargetLanguage.spanish.ttsLocale, 'es-ES');
      expect(TargetLanguage.italian.ttsLocale, 'it-IT');
    });
  });

  group('UserProfileRepository', () {
    test('heç nə saxlanmayıbsa profil yoxdur (onboarding lazım)', () async {
      final repo = await UserProfileRepository.load();
      expect(repo.current, isNull);
      expect(repo.isOnboarded, isFalse);
    });

    test('save sonra profil geri oxunur', () async {
      final repo = await UserProfileRepository.load();
      const p = UserProfile(
        wakeHour: 6,
        sleepHour: 22,
        purpose: LearningPurpose.general,
        level: ProficiencyLevel.intermediate,
        interests: ['musiqi'],
      );
      await repo.save(p);

      final reloaded = await UserProfileRepository.load();
      expect(reloaded.isOnboarded, isTrue);
      expect(reloaded.current!.purpose, LearningPurpose.general);
      expect(reloaded.current!.interests, ['musiqi']);
    });
  });
}
