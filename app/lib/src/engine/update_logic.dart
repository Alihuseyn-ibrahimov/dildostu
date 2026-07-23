import '../models/app_version_info.dart';

/// `checkForUpdate`-in nəticəsi — yeniləmə varsa versiya + yerli APK yolu.
typedef UpdateAvailable = ({AppVersionInfo versionInfo, String apkPath});

/// Plugin-siz, test oluna bilən nüvə: serverin versiyasını cari quraşdırılmış
/// versiya ilə müqayisə edir; yenidirsə APK-nı yükləyir. `fetchVersion` və
/// `downloadApk` inject olunur (main.dart-da AppUpdateClient-ə bağlanır).
Future<UpdateAvailable?> checkForUpdate({
  required int currentVersionCode,
  required Future<AppVersionInfo?> Function() fetchVersion,
  required Future<String?> Function() downloadApk,
}) async {
  final info = await fetchVersion();
  if (info == null) return null;
  if (info.versionCode <= currentVersionCode) return null;
  final path = await downloadApk();
  if (path == null) return null; // yükləmə uğursuz — banner göstərmə
  return (versionInfo: info, apkPath: path);
}
