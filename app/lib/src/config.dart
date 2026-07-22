/// App konfiqurasiyası.
///
/// [serverBaseUrl] DilDostu Live backend-in ünvanıdır. Lokal testdə bu,
/// serveri işlədən kompüterin LAN IP-si olmalıdır (telefon eyni Wi-Fi-də),
/// məs. http://192.168.1.100:8000. Deploy-da VPS domeni.
///
/// Server əlçatmaz olsa app statik paketlərə düşür (LiveContentClient fallback).
class AppConfig {
  static const String serverBaseUrl = String.fromEnvironment(
    'DILDOSTU_SERVER_URL',
    defaultValue: 'http://192.168.0.1:8000',
  );
}
