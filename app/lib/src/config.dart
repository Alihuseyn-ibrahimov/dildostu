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
    // Daimi VPS backend (Cloudflare arxasında HTTPS). Telefon internetlə
    // qoşulur — USB/adb reverse lazım deyil.
    defaultValue: 'https://dildostu.prdostu.com',
  );
}
