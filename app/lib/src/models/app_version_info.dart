/// Serverin `/app/version` cavabı — ən son buraxılış.
class AppVersionInfo {
  const AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    this.notes = '',
  });

  final int versionCode;
  final String versionName;
  final String notes;

  factory AppVersionInfo.fromServerJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      versionCode: json['version_code'] as int,
      versionName: json['version_name'] as String,
      notes: json['notes'] as String? ?? '',
    );
  }
}
