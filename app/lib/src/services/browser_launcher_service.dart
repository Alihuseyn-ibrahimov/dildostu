import 'package:flutter/services.dart';

const _channel = MethodChannel('dildostu/browser');

/// Xarici keçidi (URL) sistemin brauzerində açır — native Intent ilə
/// (MainActivity.kt), `url_launcher` paketi olmadan. Bu maşında həmin
/// paketin Android alt-modulu pub-cache/antivirus toqquşması səbəbindən
/// qurula bilmirdi (eyni problem əvvəllər workmanager_android/open_filex-də
/// də olub) — native kanal daha etibarlı çıxdı.
class BrowserLauncherService {
  /// Xəta olarsa (nadir, məs. cihazda brauzer yoxdur) səssizcə keçir.
  Future<void> openUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {
      // İstifadəçini bloklamamalı.
    }
  }
}
