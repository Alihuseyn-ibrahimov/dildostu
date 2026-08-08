import 'package:dildostu/src/models/app_version_info.dart';
import 'package:dildostu/src/ui/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'locale_test_harness.dart';

const _info = AppVersionInfo(versionCode: 5, versionName: '1.0.0+5');

Widget _banner({
  UpdateStage stage = UpdateStage.available,
  double? progress,
  VoidCallback? onInstall,
}) =>
    wrapWithLocale(Scaffold(
      body: UpdateBanner(
        info: _info,
        onInstall: onInstall ?? () {},
        stage: stage,
        progress: progress,
      ),
    ));

void main() {
  testWidgets('versiya adını göstərir və Yenilə düyməsi çağırır', (tester) async {
    var installed = false;
    await tester.pumpWidget(_banner(onInstall: () => installed = true));
    expect(find.textContaining('1.0.0+5'), findsOneWidget);
    await tester.tap(find.text('Yenilə'));
    expect(installed, isTrue);
  });

  testWidgets('yüklənərkən faiz və göstərici görünür, düymə gizlənir',
      (tester) async {
    await tester.pumpWidget(
        _banner(stage: UpdateStage.downloading, progress: 0.42));
    expect(find.textContaining('42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // Yüklənərkən təkrar toxunuş olmasın.
    expect(find.text('Yenilə'), findsNothing);
  });

  testWidgets('ölçü bilinmirsə faizsiz "Yüklənir…" göstərir', (tester) async {
    await tester.pumpWidget(_banner(stage: UpdateStage.downloading));
    expect(find.text('Yüklənir…'), findsOneWidget);
  });

  testWidgets('uğursuzluqda xəta mətni + Yenidən cəhd et düyməsi',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(_banner(
      stage: UpdateStage.failed,
      onInstall: () => retried = true,
    ));
    expect(find.textContaining('Yüklənmədi'), findsOneWidget);
    await tester.tap(find.text('Yenidən cəhd et'));
    expect(retried, isTrue);
  });
}
