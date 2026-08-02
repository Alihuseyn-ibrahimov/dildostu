import 'package:flutter/services.dart';

const _channel = MethodChannel('dildostu/battery');

/// Android-in batareya optimallaşdırması (Doze) istisnasını idarə edir —
/// fon rutin toplamasının (WorkManager) etibarlı işləməsi üçün vacibdir.
/// MainActivity.kt-dəki native tərəf ilə əlaqələnir (yeni plugin asılılığı
/// yoxdur — Windows-da keçmiş plugin build problemlərindən qaçınmaq üçün).
class BatteryOptimizationService {
  /// Proqram artıq istisna edilibmi. Kanal xətası olarsa (nadir) `true`
  /// qaytarır — bloklayıcı vəziyyət yaratmamaq üçün.
  Future<bool> isIgnoringOptimizations() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Sistemin "İstisna et" dialoqunu açır. Xəta halında səssiz keçir.
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (_) {
      // İstifadəçini bloklamamalı.
    }
  }
}
