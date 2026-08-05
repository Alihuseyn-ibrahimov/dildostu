import 'package:dildostu/src/data/tts_telemetry_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('heç nə saxlanmayıbsa boş sayğac qaytarır', () async {
    final repo = await TtsTelemetryRepository.load();
    expect(repo.current.attempts, 0);
    expect(repo.current.failures, 0);
    expect(repo.current.noVoiceDetections, 0);
    expect(repo.current.failureRate, 0);
  });

  test('recordAttempt/recordFailure sayğacı artırır və saxlayır', () async {
    final repo = await TtsTelemetryRepository.load();
    await repo.recordAttempt();
    await repo.recordAttempt();
    await repo.recordFailure();

    expect(repo.current.attempts, 2);
    expect(repo.current.failures, 1);
    expect(repo.current.failureRate, 0.5);

    final reloaded = await TtsTelemetryRepository.load();
    expect(reloaded.current.attempts, 2);
    expect(reloaded.current.failures, 1);
  });

  test('recordNoVoiceDetected ayrıca sayılır', () async {
    final repo = await TtsTelemetryRepository.load();
    await repo.recordNoVoiceDetected();
    await repo.recordNoVoiceDetected();

    expect(repo.current.noVoiceDetections, 2);
    expect(repo.current.attempts, 0);
  });

  test('since ilk yaradılan andan dəyişmir (yenidən yükləmə sıfırlamır)',
      () async {
    final repo = await TtsTelemetryRepository.load();
    final firstSince = repo.current.since;
    await repo.recordAttempt();

    final reloaded = await TtsTelemetryRepository.load();
    expect(reloaded.current.since, firstSince);
  });
}
