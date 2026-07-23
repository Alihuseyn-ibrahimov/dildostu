import 'package:workmanager/workmanager.dart';

import '../config.dart';
import '../data/device_id_repository.dart';
import '../data/routine_client.dart';
import '../data/user_profile_repository.dart';
import '../engine/routine_logic.dart';
import 'location_service.dart';

/// Rutin nümunə toplamanın WorkManager qatı. Faktiki məntiq
/// `engine/routine_logic.dart`-da test olunur; bura yalnız nazik plumbing-dir.
///
/// Periodik iş arxa fon izolatında `callbackDispatcher`-i çağırır: cari məkanı
/// təyin edib serverə göndərir (aktiv saatlarda). İcazə/GPS/şəbəkə yoxdursa
/// səssiz keçir. Arxa fon məkan icazəsi tələb olunur (main.dart icazə axını).
class RoutineSampler {
  static const _taskName = 'dildostu.routine.sample';
  static const _uniqueName = 'dildostu-routine-periodic';

  /// main() içində, plugin işə salınandan əvvəl çağırılır.
  static Future<void> initialize() =>
      Workmanager().initialize(callbackDispatcher);

  /// Periodik toplamanı qeydə alır (min 15 dəq — Android aşağı dəyəri 15-ə çəkir).
  static Future<void> registerPeriodic() => Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: const Duration(minutes: 20),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );

  /// İstifadəçi rutin toplamanı söndürəndə.
  static Future<void> cancel() =>
      Workmanager().cancelByUniqueName(_uniqueName);
}

/// Arxa fon izolatının giriş nöqtəsi — periodik iş vaxtı Android çağırır.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final profileRepo = await UserProfileRepository.load();
      final profile = profileRepo.current;
      // Profil yoxdursa (onboarding olmayıb) toplama.
      if (profile == null) return true;

      // Yalnız aktiv saatlarda topla.
      if (!isWithinActiveHours(
          DateTime.now().hour, profile.wakeHour, profile.sleepHour)) {
        return true;
      }

      final deviceId = (await DeviceIdRepository.load()).deviceId;
      final location = LocationService();
      final client = RoutineClient(baseUrl: AppConfig.serverBaseUrl);
      await takeRoutineSample(
        resolve: location.resolveNearbySample,
        client: client,
        deviceId: deviceId,
      );
      return true;
    } catch (_) {
      // Fon işi heç vaxt sınmamalı — uğursuzsa belə true qaytar (təkrar yığılmasın).
      return true;
    }
  });
}
