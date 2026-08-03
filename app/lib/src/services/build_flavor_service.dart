import 'package:flutter/services.dart';

const _channel = MethodChannel('dildostu/build_flavor');

/// Android tərəfdən (MainActivity.kt) hansı "flavor"-ın (direct/play)
/// qurulduğunu soruşur. Bu, `play` flavor-un manifestindəki meta-data-dan
/// gəlir (bax android/app/src/play/AndroidManifest.xml).
///
/// Google Play buraxılışında self-update və arxa fon məkan UI-larını
/// gizlətmək üçün işlədilir — Play siyasəti bunları qadağan edir.
class BuildFlavorService {
  /// Kanal xətası olarsa (nadir, məs. testdə) `false` qaytarır — "direct"
  /// davranışına (bugünkü tam funksionallıq) düşür, funksiyanı gizlətmir.
  Future<bool> isPlayBuild() async {
    try {
      return await _channel.invokeMethod<bool>('isPlayBuild') ?? false;
    } catch (_) {
      return false;
    }
  }
}
