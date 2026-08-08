import 'package:dildostu/src/data/device_lock_repository.dart';
import 'package:dildostu/src/ui/unlock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'locale_test_harness.dart';

void main() {
  testWidgets('düzgün PIN kilidi açır', (tester) async {
    final storage = InMemoryLockStorage();
    final repo = await DeviceLockRepository.load(storageForTest: storage);
    await repo.setPin('1234');

    var unlocked = false;
    await tester.pumpWidget(wrapWithLocale(UnlockScreen(
      lockRepo: repo,
      onUnlocked: () => unlocked = true,
      onRequireFullLogin: () {},
      authenticateBiometric: (_) async => false,
    )));

    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
  });
}
