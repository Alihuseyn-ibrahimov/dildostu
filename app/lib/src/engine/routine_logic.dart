import '../data/routine_client.dart';

/// Rutin toplamanın plugin-siz, test oluna bilən nüvəsi. WorkManager plumbing-i
/// `services/routine_sampler.dart`-dadır; bu fayl heç bir plugin idxal etmir.

/// Bir məkan nümunəsi: koordinat + təyin olunmuş pack/məkan tipi.
typedef RoutineSample = ({double lat, double lng, String packId});

/// `hour` aktiv saat pəncərəsindədirmi (oyanış–yatış). Gecəyə keçən pəncərəni də
/// düzgün işləyir (məs. wake=22, sleep=6 → 23 və 3 aktivdir, 12 yox).
bool isWithinActiveHours(int hour, int wakeHour, int sleepHour) {
  if (wakeHour == sleepHour) return true; // 24 saat aktiv
  if (wakeHour < sleepHour) {
    return hour >= wakeHour && hour < sleepHour;
  }
  // Gecəyə keçir (wake > sleep): [wake..24) və [0..sleep)
  return hour >= wakeHour || hour < sleepHour;
}

/// Bir dəfə nümunə götür: `resolve` cari məkanı təyin edir; nəticə varsa serverə
/// göndərir. Məkan təyin olunmasa (icazə/GPS/şəbəkə yox) səssiz keçir.
///
/// `resolve` və `client` inject olunur → plugin-siz test.
Future<void> takeRoutineSample({
  required Future<RoutineSample?> Function() resolve,
  required RoutineClient client,
  required String deviceId,
}) async {
  final sample = await resolve();
  if (sample == null) return;
  await client.postSample(
    deviceId: deviceId,
    lat: sample.lat,
    lng: sample.lng,
    placeType: sample.packId,
    packId: sample.packId,
  );
}
