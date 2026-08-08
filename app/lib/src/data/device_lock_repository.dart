import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kilid məlumatının saxlanması — testdə in-memory.
abstract class LockStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureLockStorage implements LockStorage {
  SecureLockStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemoryLockStorage implements LockStorage {
  final _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

/// Cihaz kilidi — PIN hash + biometrik seçimi secure storage-də.
class DeviceLockRepository {
  DeviceLockRepository._(this._storage);

  static const _pinHashKey = 'dildostu.lock.pin_hash.v1';
  static const _pinSaltKey = 'dildostu.lock.pin_salt.v1';
  static const _biometricKey = 'dildostu.lock.biometric.v1';
  static const _maxAttempts = 5;

  final LockStorage _storage;
  int _failedAttempts = 0;

  bool get isLockedOut => _failedAttempts >= _maxAttempts;

  /// PIN təyin olunubsa kilid aktiv sayılır.
  Future<bool> isEnabled() async {
    final hash = await _storage.read(_pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> isBiometricEnabled() async {
    final v = await _storage.read(_biometricKey);
    return v == '1';
  }

  Future<void> setPin(String pin) async {
    _assertPinFormat(pin);
    final salt = _randomSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(_pinSaltKey, salt);
    await _storage.write(_pinHashKey, hash);
    _failedAttempts = 0;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(_biometricKey, enabled ? '1' : '0');
  }

  /// Düzgün PIN → true; səhv → false; limit dolubsa `DeviceLockLockedOut`.
  Future<bool> verifyPin(String pin) async {
    if (isLockedOut) throw const DeviceLockLockedOut();
    final salt = await _storage.read(_pinSaltKey);
    final expected = await _storage.read(_pinHashKey);
    if (salt == null || expected == null) return false;
    final ok = _hashPin(pin, salt) == expected;
    if (ok) {
      _failedAttempts = 0;
      return true;
    }
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) throw const DeviceLockLockedOut();
    return false;
  }

  Future<void> clear() async {
    await _storage.delete(_pinHashKey);
    await _storage.delete(_pinSaltKey);
    await _storage.delete(_biometricKey);
    _failedAttempts = 0;
  }

  static Future<DeviceLockRepository> load({LockStorage? storageForTest}) async {
    return DeviceLockRepository._(storageForTest ?? SecureLockStorage());
  }

  void _assertPinFormat(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN 4 rəqəm olmalıdır');
    }
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  String _randomSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}

/// Ardıcıl səhv PIN limiti dolub — tam giriş tələb olunur.
class DeviceLockLockedOut implements Exception {
  const DeviceLockLockedOut();
}
