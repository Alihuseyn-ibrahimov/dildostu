import 'package:flutter/material.dart';

import '../data/auth_client.dart';
import 'theme.dart';

typedef AuthAction = Future<AuthResult> Function(String email, String password);

/// Giriş / Qeydiyyat ekranı — hesab sistemi olmadan tətbiq açılmır (spec:
/// Faza 3, "hər kəs öz kabinetini yaradıb daxil olsun").
///
/// `register`/`login` inject olunur (main.dart-da `AuthClient`-ə bağlanır) —
/// ekran HTTP-dən asılı deyil, mock ilə test olunur.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.register,
    required this.login,
    required this.onAuthenticated,
  });

  final AuthAction register;
  final AuthAction login;

  /// Uğurlu giriş/qeydiyyatdan sonra çağırılır (token, email).
  final void Function(String token, String email) onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'E-poçt və şifrəni daxil et.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final action = _isRegisterMode ? widget.register : widget.login;
      final result = await action(email, password);
      widget.onAuthenticated(result.token, result.email);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionLabel = _isRegisterMode ? 'Qeydiyyatdan keç' : 'Giriş';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.translate, size: 56),
                const SizedBox(height: 12),
                Text('DilDostu',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _isRegisterMode
                      ? 'Öz kabinetini yarat'
                      : 'Kabinetinə daxil ol',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: AppSpacing.section),
                TextField(
                  key: const Key('login_email'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'E-poçt',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('login_password'),
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Şifrə',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: AppSpacing.section),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : Text(actionLabel),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _isRegisterMode = !_isRegisterMode;
                            _error = null;
                          }),
                  child: Text(
                    _isRegisterMode
                        ? 'Artıq hesabın var? Giriş et'
                        : 'Hesabın yoxdur? Qeydiyyatdan keç',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
