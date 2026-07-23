import 'package:flutter/material.dart';

import '../models/app_version_info.dart';

/// Yeni versiya yükləndikdə HomeScreen-in yuxarısında göstərilən zolaq.
/// `onInstall` toxunanda yüklənmiş APK-nı sistem quraşdırıcısına açır
/// (main.dart-da OpenFilex-ə bağlanır — bir toxunuşla Android təsdiqi açılır).
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.info, required this.onInstall});

  final AppVersionInfo info;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.system_update),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Yeni versiya hazırdır (${info.versionName})'),
            ),
            FilledButton(onPressed: onInstall, child: const Text('Yenilə')),
          ],
        ),
      ),
    );
  }
}
