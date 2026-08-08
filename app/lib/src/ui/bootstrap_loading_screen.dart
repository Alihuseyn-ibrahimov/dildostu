import 'dart:async';

import 'package:flutter/material.dart';

import 'brand.dart';
import 'brand_logo.dart';

/// Bootstrap (açılış) yükləmə ekranı — peşəkar splash UX.
///
/// Duolingo/Babbel nümunəsi: brend gradienti, mərkəzdə ikon, aşağıda progress.
/// Status mesajları dövr edir ki, istifadəçi "donub" hiss etməsin.
class BootstrapLoadingScreen extends StatefulWidget {
  const BootstrapLoadingScreen({super.key});

  @override
  State<BootstrapLoadingScreen> createState() => _BootstrapLoadingScreenState();
}

class _BootstrapLoadingScreenState extends State<BootstrapLoadingScreen>
    with SingleTickerProviderStateMixin {
  static const _messages = [
    'LachinGo hazırlanır…',
    'Profilin yüklənir…',
    'Dil paketləri açılır…',
    'Səyahətə hazır ol…',
  ];

  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: BrandColors.splashGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                const Spacer(flex: 3),
                const BrandLogo(
                  height: 112,
                  variant: BrandLogoVariant.icon,
                  animate: true,
                ),
                const SizedBox(height: 20),
                const BrandTitle(fontSize: 32),
                const SizedBox(height: 8),
                Text(
                  kBrandTagline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: BrandColors.navy.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Text(
                          _messages[_messageIndex],
                          key: ValueKey(_messageIndex),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: BrandColors.navy.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor:
                              BrandColors.navy.withValues(alpha: 0.12),
                          color: BrandColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
