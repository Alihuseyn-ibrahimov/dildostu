import 'package:dildostu/src/models/app_version_info.dart';
import 'package:dildostu/src/ui/update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('versiya adını göstərir və Yenilə düyməsi çağırır', (tester) async {
    var installed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UpdateBanner(
          info: const AppVersionInfo(versionCode: 5, versionName: '1.0.0+5'),
          onInstall: () => installed = true,
        ),
      ),
    ));
    expect(find.textContaining('1.0.0+5'), findsOneWidget);
    await tester.tap(find.text('Yenilə'));
    expect(installed, isTrue);
  });
}
