import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../data/device_lock_repository.dart';
import '../l10n/app_locale_scope.dart';
import 'theme.dart';

/// Soyuq başlanğıcda PIN və ya biometrik kilid — sessiya var, amma cihazı
/// başqası açmasın deyə.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    super.key,
    required this.lockRepo,
    required this.onUnlocked,
    required this.onRequireFullLogin,
    this.authenticateBiometric,
  });

  final DeviceLockRepository lockRepo;
  final VoidCallback onUnlocked;

  /// Limit dolub və ya istifadəçi "Tam giriş" seçəndə.
  final VoidCallback onRequireFullLogin;

  /// Test üçün inject — default `LocalAuthentication().authenticate`.
  final Future<bool> Function(String reason)? authenticateBiometric;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _localAuth = LocalAuthentication();
  String _pin = '';
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (_busy) return;
    final enabled = await widget.lockRepo.isBiometricEnabled();
    if (!enabled || !mounted) return;

    setState(() => _busy = true);
    try {
      final ok = await (widget.authenticateBiometric ??
          (reason) async {
            final can = await _localAuth.canCheckBiometrics;
            if (!can) return false;
            return _localAuth.authenticate(
              localizedReason: reason,
              options: const AuthenticationOptions(
                stickyAuth: true,
                biometricOnly: true,
              ),
            );
          })(context.s.unlockBiometricReason);
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {
      // Biometrik uğursuz — PIN fallback qalır.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitPin() async {
    if (_pin.length < 4 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.lockRepo.verifyPin(_pin);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
        return;
      }
      setState(() {
        _pin = '';
        _error = context.s.unlockWrongPin;
      });
    } on DeviceLockLockedOut {
      if (mounted) widget.onRequireFullLogin();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDigit(String d) {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _submitPin();
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                s.unlockTitle,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                s.unlockSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              _PinPad(
                onDigit: _onDigit,
                onBackspace: _backspace,
                disabled: _busy,
              ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : _tryBiometric,
                child: Text(s.unlockUseBiometric),
              ),
              TextButton(
                onPressed: _busy ? null : widget.onRequireFullLogin,
                child: Text(s.unlockFullLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.onDigit,
    required this.onBackspace,
    required this.disabled,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: [
        for (final row in keys)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final key in row)
                _PinKey(
                  label: key,
                  onTap: disabled
                      ? null
                      : () {
                          if (key.isEmpty) return;
                          if (key == '⌫') {
                            onBackspace();
                          } else {
                            onDigit(key);
                          }
                        },
                ),
            ],
          ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox(width: 72, height: 56);
    }
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 60,
            height: 48,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ayarlarda PIN təyin/dəyişmə dialoqu. Uğurlu olsa true.
Future<bool> showPinSetupDialog(
  BuildContext context,
  DeviceLockRepository lockRepo,
) async {
  final s = context.s;
  final pinController = TextEditingController();
  final confirmController = TextEditingController();
  String? error;
  String? savedPin;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(s.setPinTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: s.pinHint,
                    counterText: '',
                  ),
                ),
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: s.pinConfirmHint,
                    counterText: '',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final pin = pinController.text;
                  final confirm = confirmController.text;
                  if (pin.length != 4) {
                    setLocal(() => error = s.pinMustBeFourDigits);
                    return;
                  }
                  if (pin != confirm) {
                    setLocal(() => error = s.pinMismatch);
                    return;
                  }
                  savedPin = pin;
                  Navigator.of(ctx).pop(true);
                },
                child: Text(s.save),
              ),
            ],
          );
        },
      );
    },
  );

  pinController.dispose();
  confirmController.dispose();
  if (ok != true || savedPin == null) return false;

  try {
    await lockRepo.setPin(savedPin!);
    return true;
  } catch (_) {
    return false;
  }
}
