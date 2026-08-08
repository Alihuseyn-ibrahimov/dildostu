import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';
import '../models/chat_quota.dart';

/// Gündəlik söhbət kvotasını göstərir — söhbət ekranının yuxarısında.
class ChatQuotaBar extends StatelessWidget {
  const ChatQuotaBar({super.key, this.quota});

  /// Null olsa zolaq göstərilmir (yüklənmə uğursuz və ya loader yoxdur).
  final ChatQuota? quota;

  @override
  Widget build(BuildContext context) {
    final q = quota;
    if (q == null) return const SizedBox.shrink();

    final s = context.s;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = q.isExhausted
        ? colors.error
        : q.isLow
            ? colors.tertiary
            : colors.primary;

    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.chat_outlined, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.chatQuotaSummary(q.used, q.limit),
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                Text(
                  s.chatQuotaRemaining(q.remaining),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: q.isLow ? accent : colors.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: q.fraction.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: colors.outlineVariant,
                color: accent,
              ),
            ),
            if (q.isExhausted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.chatQuotaExhausted,
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
