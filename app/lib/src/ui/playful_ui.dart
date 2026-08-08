import 'package:flutter/material.dart';

import 'brand.dart';
import 'theme.dart';

/// Duolingo tipli 3D kart — alt kölgə ilə "basıla bilən" hissi.
///
/// LachinGo fərqi: rəng palitrası göy+qızıl səyahət brendindən gəlir,
/// yaşıl yol ağacı yox — "pasport möhürü" / "missiya kartı" kimi işlədilir.
class PlayfulCard extends StatelessWidget {
  const PlayfulCard({
    super.key,
    required this.color,
    required this.shadowColor,
    required this.child,
    this.onTap,
    this.borderRadius = AppSpacing.radiusPlayful,
    this.padding = const EdgeInsets.all(16),
  });

  final Color color;
  final Color shadowColor;
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsets padding;

  /// Aksent rəngdən avtomatik kölgə — 15% tündləşmə.
  static Color shadowFor(Color base) =>
      Color.lerp(base, Colors.black, 0.22)!;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: shadowColor.withValues(alpha: 0.15),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Bölmə başlığı — rəngli ikon + qalın mətn (Duolingo section header).
class PlayfulSectionHeader extends StatelessWidget {
  const PlayfulSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.emoji,
    this.accent = BrandColors.navy,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? emoji;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: 18))
              : Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pill seçici — səviyyə/dil üçün (SegmentedButton əvəzinə daha oyunvari).
class PlayfulPillSelector<T> extends StatelessWidget {
  const PlayfulPillSelector({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelFor,
    this.accent = BrandColors.navy,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelFor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          _PlayfulPill(
            label: labelFor(v),
            selected: v == selected,
            accent: accent,
            onTap: () => onChanged(v),
          ),
      ],
    );
  }
}

class _PlayfulPill extends StatelessWidget {
  const _PlayfulPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? accent : theme.colorScheme.surface;
    final shadow = selected ? PlayfulCard.shadowFor(accent) : theme.colorScheme.outlineVariant;
    final fg = selected ? Colors.white : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? shadow : theme.colorScheme.outlineVariant,
              width: selected ? 0 : 1.5,
            ),
            boxShadow: selected
                ? [BoxShadow(color: shadow, offset: const Offset(0, 3), blurRadius: 0)]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ana səhifə hero başlığı — səyahət gradienti + salamlama.
class PlayfulHomeHero extends StatelessWidget {
  const PlayfulHomeHero({
    super.key,
    required this.greeting,
    required this.headline,
    this.trailing,
  });

  final String greeting;
  final String headline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BrandColors.navy,
            BrandColors.navy.withValues(alpha: 0.85),
            const Color(0xFF2A6CB8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPlayful),
        boxShadow: [
          BoxShadow(
            color: PlayfulCard.shadowFor(BrandColors.navy),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  headline,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hər yer yeni sözlər deməkdir ✈️',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BrandColors.gold.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Səhifə fonu — yumşaq səma gradienti (Duolingo tam ağ deyil).
class PlayfulScreenBackground extends StatelessWidget {
  const PlayfulScreenBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF0F6FC),
            Color(0xFFFAFCFE),
            Colors.white,
          ],
          stops: [0.0, 0.35, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// Kiçik "missiya" etiketi — kartların küncündə.
class PlayfulBadge extends StatelessWidget {
  const PlayfulBadge({super.key, required this.label, this.color = BrandColors.gold});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: PlayfulCard.shadowFor(color),
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
      ),
    );
  }
}
