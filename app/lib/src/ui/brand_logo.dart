import 'package:flutter/material.dart';

import 'brand.dart';

/// Loqo variantı: tam wordmark və ya yalnız ikon (splash/bootstrap).
enum BrandLogoVariant { wordmark, icon }

/// LachinGo brend loqosu.
///
/// `assets/branding/logo_wordmark.png` — tam wordmark (giriş ekranı).
/// `assets/branding/logo_icon.png` — ikon (yükləmə, native splash uyğunluğu).
class BrandLogo extends StatefulWidget {
  const BrandLogo({
    super.key,
    this.height = 72,
    this.variant = BrandLogoVariant.wordmark,
    this.animate = false,
  });

  final double height;
  final BrandLogoVariant variant;

  /// Yükləmə ekranında yüngül "üzmə" animasiyası.
  final bool animate;

  static const _wordmarkAsset = 'assets/branding/logo_wordmark.png';
  static const _iconAsset = 'assets/branding/logo_icon.png';

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _float;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat(reverse: true);
      _float = Tween<double>(begin: -5, end: 5).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void didUpdateWidget(covariant BrandLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat(reverse: true);
      _float = Tween<double>(begin: -5, end: 5).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    } else if (!widget.animate && _controller != null) {
      _controller!.dispose();
      _controller = null;
      _float = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.variant == BrandLogoVariant.wordmark
        ? BrandLogo._wordmarkAsset
        : BrandLogo._iconAsset;

    Widget image = Image.asset(
      asset,
      height: widget.height,
      fit: BoxFit.contain,
      semanticLabel: 'LachinGo',
    );

    if (_float != null) {
      image = AnimatedBuilder(
        animation: _float!,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _float!.value), child: child),
        child: image,
      );
    }

    return image;
  }
}

/// Wordmark olmadan brend adı — ikon altında istifadə olunur.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.fontSize = 28});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        children: const [
          TextSpan(
            text: 'Lachin',
            style: TextStyle(color: BrandColors.navy),
          ),
          TextSpan(
            text: 'Go',
            style: TextStyle(color: BrandColors.gold),
          ),
        ],
      ),
    );
  }
}
