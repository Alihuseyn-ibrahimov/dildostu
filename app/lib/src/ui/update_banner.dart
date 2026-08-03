import 'package:flutter/material.dart';

import '../models/app_version_info.dart';

/// "Yenilə" zolağının vəziyyəti — yükləmə uzun sürdüyü üçün (150+ MB)
/// istifadəçi hər mərhələni görməlidir.
enum UpdateStage {
  /// Yeni versiya aşkarlandı, yükləmə hələ başlamayıb (istifadəçi başladır).
  available,

  /// Yüklənir — faiz göstərilir.
  downloading,

  /// Yükləmə uğursuz oldu — "Yenidən cəhd et" göstərilir.
  failed,
}

/// Yeni versiya aşkarlandıqda HomeScreen-in yuxarısında görünən zolaq.
///
/// Zolaq versiya yoxlanışından DƏRHAL sonra görünür (yükləməni gözləmir) —
/// əvvəl 150+ MB tam yüklənənə qədər heç nə göstərilmirdi və zolaq praktikada
/// heç vaxt çıxmırdı (bax `update_logic.dart`).
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.info,
    required this.onInstall,
    this.stage = UpdateStage.available,
    this.progress,
  });

  final AppVersionInfo info;

  /// "Yenilə" / "Yenidən cəhd et" toxunuşu — yükləməni başladır.
  final VoidCallback onInstall;

  final UpdateStage stage;

  /// 0.0-1.0 arası yükləmə faizi; server ölçü verməsə null (qeyri-müəyyən).
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloading = stage == UpdateStage.downloading;

    final String text;
    if (downloading) {
      final percent = progress == null ? null : (progress! * 100).round();
      text = percent == null ? 'Yüklənir…' : 'Yüklənir… $percent%';
    } else if (stage == UpdateStage.failed) {
      text = 'Yüklənmədi — internetini yoxla';
    } else {
      text = 'Yeni versiya var (${info.versionName})';
    }

    return Material(
      color: theme.colorScheme.primaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(stage == UpdateStage.failed
                    ? Icons.error_outline
                    : Icons.system_update),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
                if (downloading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else
                  FilledButton(
                    onPressed: onInstall,
                    child: Text(stage == UpdateStage.failed
                        ? 'Yenidən cəhd et'
                        : 'Yenilə'),
                  ),
              ],
            ),
          ),
          if (downloading)
            LinearProgressIndicator(value: progress, minHeight: 3),
        ],
      ),
    );
  }
}
