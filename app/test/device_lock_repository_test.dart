import 'package:dildostu/src/data/device_lock_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PIN təyin və yoxlama', () async {
    final storage = InMemoryLockStorage();
    final repo = await DeviceLockRepository.load(storageForTest: storage);
    expect(await repo.isEnabled(), isFalse);

    await repo.setPin('1234');
    expect(await repo.isEnabled(), isTrue);
    expect(await repo.verifyPin('1234'), isTrue);
    expect(await repo.verifyPin('0000'), isFalse);
  });

  test('5 səhv cəhddən sonra locked out', () async {
    final storage = InMemoryLockStorage();
    final repo = await DeviceLockRepository.load(storageForTest: storage);
    await repo.setPin('1234');

    for (var i = 0; i < 4; i++) {
      expect(await repo.verifyPin('0000'), isFalse);
    }
    expect(() => repo.verifyPin('0000'), throwsA(isA<DeviceLockLockedOut>()));
  });

  test('clear kilidi söndürür', () async {
    final storage = InMemoryLockStorage();
    final repo = await DeviceLockRepository.load(storageForTest: storage);
    await repo.setPin('1234');
    await repo.clear();
    expect(await repo.isEnabled(), isFalse);
  });
}
