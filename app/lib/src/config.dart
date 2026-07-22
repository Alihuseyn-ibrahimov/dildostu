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
    // USB-qoşulu cihaz üçün `adb reverse tcp:8000 tcp:8000` ilə telefonun
    // localhost:8000-i kompüterdəki serverə yönləndirilir.
    defaultValue: 'http://localhost:8000',
  );
}
