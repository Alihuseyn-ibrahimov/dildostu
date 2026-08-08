import 'package:dildostu/src/engine/chat_nudge_templates.dart';
import 'package:dildostu/src/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = UserProfile(
    wakeHour: 8,
    sleepHour: 23,
    purpose: LearningPurpose.travel,
    level: ProficiencyLevel.beginner,
    interests: ['foto'],
  );

  test('lokal fallback 3 slot qaytarır', () {
    final nudges = buildLocalChatNudges(profile);
    expect(nudges, hasLength(3));
  });

  test('fərqli günlərdə səhər mesajı dəyişə bilər', () {
    final a = buildLocalChatNudges(
      profile,
      onDay: DateTime(2026, 8, 7),
    );
    final b = buildLocalChatNudges(
      profile,
      onDay: DateTime(2026, 8, 8),
    );
    expect(a[0].body == b[0].body, isFalse);
  });
}
