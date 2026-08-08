import 'package:flutter/material.dart';

import '../data/review_repository.dart';
import '../engine/review_engine.dart';
import '../models/live_message.dart';
import '../models/user_profile.dart';
import '../services/speaker.dart';
import 'accent_colors.dart';
import 'theme.dart';

/// `/generate` endpoint-i ilə eyni kontekstdə yeni söz yaradır.
///
/// `mode`: `another_example`, `simpler`, `harder`.
typedef AiWordGenerator = Future<LiveMessage> Function({
  required String packId,
  required String mode,
  required List<String> recentWords,
});

/// Bir sözün ətraflı ekranı — söz, IPA, tərcümə, nümunə cümlə, səsləndirmə.
/// Aşağıda "Əvvəlki / Növbəti" keçidləri: istifadəçi siyahıya qayıtmadan
/// sözlər arasında rahat gəzir (sürüşdürmə də işləyir).
class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({
    super.key,
    required this.title,
    required this.words,
    required this.speaker,
    this.initialIndex = 0,
    this.onAskQuestion,
    this.onAiWord,
    this.accent,
    this.reviewRepository,
  });

  final String title;
  final List<LiveMessage> words;
  final Speaker speaker;
  final int initialIndex;

  /// "Sual ver" — AI söhbətini bu kontekstlə açır (main.dart bağlayır).
  final VoidCallback? onAskQuestion;

  /// Canlı AI ilə eyni paket kontekstində başqa/sadə/çətin söz yaradır.
  /// Null olsa düymələr göstərilmir (məs. test).
  final AiWordGenerator? onAiWord;

  /// Paketin sabit aksent rəngi (bax `accent_colors.dart`). Null olsa
  /// mövcud neytral tema rəngləri işlədilir.
  final AccentColor? accent;

  /// Verilsə, söz açılanda və "Bilirəm/Təkrar" cavabında irəliləyiş yazılır.
  final ReviewRepository? reviewRepository;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  late final PageController _controller;
  late List<LiveMessage> _words;
  late int _index;
  final Set<String> _recordedExposure = {};
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _words = List<LiveMessage>.from(widget.words);
    _index = widget.initialIndex.clamp(0, _lastIndex);
    _controller = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackCurrentWord();
    });
  }

  int get _lastIndex => _words.isEmpty ? 0 : _words.length - 1;

  LiveMessage get _current => _words[_index];

  @override
  void dispose() {
    _controller.dispose();
    widget.speaker.stop();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index > _lastIndex) return;
    widget.speaker.stop();
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _trackCurrentWord() async {
    final repo = widget.reviewRepository;
    if (repo == null || _words.isEmpty) return;
    final key = reviewWordKey(_current);
    if (_recordedExposure.contains(key)) return;
    _recordedExposure.add(key);
    await repo.recordExposure(key, now: DateTime.now(), hint: _current);
  }

  Future<void> _handleReview(ReviewOutcome outcome) async {
    final repo = widget.reviewRepository;
    if (repo == null) return;
    final key = reviewWordKey(_current);
    await repo.recordReview(key, outcome, now: DateTime.now(), hint: _current);
    if (!mounted) return;
    final step = repo.stateFor(key).step;
    final msg = outcome == ReviewOutcome.known
        ? 'Yaxşı! Mənimsəmə: $step/$masteredStepThreshold'
        : 'Tezliklə yenidən göstəriləcək';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    setState(() {});
  }

  List<String> get _recentWords =>
      _words.map((m) => m.word).where((w) => w.isNotEmpty).toList();

  Future<void> _runAiMode(String mode) async {
    final generate = widget.onAiWord;
    if (generate == null || _aiLoading || _words.isEmpty) return;

    setState(() => _aiLoading = true);
    try {
      final msg = await generate(
        packId: _current.packId,
        mode: mode,
        recentWords: _recentWords,
      );
      if (!mounted) return;
      final oldKey = reviewWordKey(_current);
      setState(() {
        _words[_index] = msg;
        _recordedExposure.remove(oldKey);
      });
      await _trackCurrentWord();
      if (!mounted) return;
      final text = msg.isLive
          ? 'Yeni söz hazırdır ✨'
          : 'Server əlçatmaz — statik söz göstərildi';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alınmadı: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('Söz yoxdur.')),
      );
    }

    final current = _current;
    final step = widget.reviewRepository?.stateFor(reviewWordKey(current)).step ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.accent?.tint,
        actions: [
          if (widget.onAskQuestion != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Sual ver',
              onPressed: widget.onAskQuestion,
            ),
          if (!current.isLive)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Offline rejim (statik)',
                child: Icon(Icons.cloud_off, size: 20),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) {
                widget.speaker.stop();
                setState(() => _index = i);
                _trackCurrentWord();
              },
              itemCount: _words.length,
              itemBuilder: (context, i) => _WordDetailBody(
                message: _words[i],
                onSpeak: () => widget.speaker.speak(_words[i].word),
                accent: widget.accent,
                showAiActions: widget.onAiWord != null,
                aiLoading: _aiLoading,
                onAiMode: _runAiMode,
              ),
            ),
          ),
          if (widget.reviewRepository != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(masteredStepThreshold, (i) {
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step > i
                          ? (widget.accent?.accent ?? theme.colorScheme.primary)
                          : theme.colorScheme.outline.withValues(alpha: 0.25),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleReview(ReviewOutcome.later),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Təkrar lazım'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _handleReview(ReviewOutcome.known),
                      style: widget.accent == null
                          ? null
                          : FilledButton.styleFrom(
                              backgroundColor: widget.accent!.accent,
                              foregroundColor: widget.accent!.onAccent,
                            ),
                      icon: const Icon(Icons.check),
                      label: const Text('Bilirəm'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, 8, AppSpacing.screen, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Əvvəlki'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('${_index + 1}/${_words.length}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _index < _lastIndex ? () => _goTo(_index + 1) : null,
                      style: widget.accent == null
                          ? null
                          : FilledButton.styleFrom(
                              backgroundColor: widget.accent!.accent,
                              foregroundColor: widget.accent!.onAccent,
                            ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Növbəti'),
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

/// Tək sözün gövdəsi (PageView səhifəsi).
class _WordDetailBody extends StatelessWidget {
  const _WordDetailBody({
    required this.message,
    required this.onSpeak,
    this.accent,
    this.showAiActions = false,
    this.aiLoading = false,
    this.onAiMode,
  });

  final LiveMessage message;
  final VoidCallback onSpeak;
  final AccentColor? accent;
  final bool showAiActions;
  final bool aiLoading;
  final void Function(String mode)? onAiMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelMatch = ProficiencyLevel.values
        .where((l) => l.wordLevel == message.level)
        .firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.screen, AppSpacing.screen, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent?.tint ?? theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            ),
            child: Row(
              children: [
                const Text('🤖  '),
                Expanded(
                  child: Text(message.aiLine,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: accent?.accent ??
                              theme.colorScheme.onPrimaryContainer)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          if (levelMatch != null)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(levelMatch.labelAz,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          const SizedBox(height: 14),
          Text(message.word,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(message.ipa,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 14),
          Text(message.translationAz,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.section),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nümunə',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 8),
                  Text(message.example, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(message.exampleAz,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
          ),
          if (showAiActions) ...[
            const SizedBox(height: AppSpacing.section),
            Text(
              'AI ilə başqa variant',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _AiModeChip(
                  label: 'Başqa söz',
                  icon: Icons.autorenew,
                  loading: aiLoading,
                  onPressed:
                      aiLoading ? null : () => onAiMode?.call('another_example'),
                  accent: accent,
                ),
                _AiModeChip(
                  label: 'Daha sadə',
                  icon: Icons.trending_down,
                  loading: aiLoading,
                  onPressed: aiLoading ? null : () => onAiMode?.call('simpler'),
                  accent: accent,
                ),
                _AiModeChip(
                  label: 'Daha çətin',
                  icon: Icons.trending_up,
                  loading: aiLoading,
                  onPressed: aiLoading ? null : () => onAiMode?.call('harder'),
                  accent: accent,
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          FilledButton.tonalIcon(
            onPressed: onSpeak,
            style: accent == null
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: accent!.tint,
                    foregroundColor: accent!.accent,
                  ),
            icon: const Icon(Icons.volume_up),
            label: const Text('Səsləndir'),
          ),
        ],
      ),
    );
  }
}

class _AiModeChip extends StatelessWidget {
  const _AiModeChip({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.loading,
    this.accent,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final AccentColor? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent?.accent ?? theme.colorScheme.primary;
    return ActionChip(
      avatar: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: 18, color: color),
      label: Text(label),
      onPressed: onPressed,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: accent?.tint ?? theme.colorScheme.surfaceContainerHighest,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
