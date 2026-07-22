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
