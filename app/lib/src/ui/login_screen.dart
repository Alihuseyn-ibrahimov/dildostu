import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';
import '../data/auth_client.dart';
import 'brand.dart';
import 'brand_logo.dart';
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
      setState(() => _error = context.s.emailPasswordRequired);
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
    final scheme = theme.colorScheme;
    final s = context.s;
    final actionLabel = _isRegisterMode ? s.registerAction : s.loginAction;

    return Scaffold(
      body: Column(
        children: [
          // Brend başlığı — Babbel tipli gradient header.
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: BrandColors.loginHeaderGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const BrandLogo(
                        height: 64,
                        variant: BrandLogoVariant.icon,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'LachinGo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.loginTagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Form sahəsi — ağ kart üslubunda.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isRegisterMode
                        ? s.loginRegisterHeadline
                        : s.loginSignInHeadline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  TextField(
                    key: const Key('login_email'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: s.emailHint,
                      prefixIcon: const Icon(Icons.mail_outline),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusControl),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('login_password'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: s.passwordHint,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusControl),
                      ),
                    ),
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
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
                      _isRegisterMode ? s.switchToLogin : s.switchToRegister,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
