import '../models/app_version_info.dart';

/// Serverdə cari quraşdırılmışdan YENİ versiya varmı — yalnız yoxlayır.
///
/// Yükləmə QƏSDƏN bu funksiyadan ayrılıb. Əvvəl banner yalnız 150+ MB APK tam
/// yükləndikdən sonra qaytarılırdı: istifadəçi app-ı açanda heç bir əlamət
/// görmürdü, arxada səssiz yükləmə gedirdi və app bağlananda itirdi —
/// nəticədə "Yenilə" zolağı praktikada heç vaxt görünmürdü. İndi zolaq
/// dərhal (kiçik JSON sorğusundan sonra) göstərilir, yükləmə isə istifadəçi
/// toxunanda, faiz göstəricisi ilə başlayır.
Future<AppVersionInfo?> checkForUpdate({
  required int currentVersionCode,
  required Future<AppVersionInfo?> Function() fetchVersion,
}) async {
  final info = await fetchVersion();
  if (info == null) return null;
  if (info.versionCode <= currentVersionCode) return null;
  return info;
}
