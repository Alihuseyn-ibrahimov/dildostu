import 'dart:async';

import 'package:flutter/material.dart';

import '../data/word_lookup_client.dart';
import '../engine/audiobook_sync.dart';
import '../engine/lyrics_sync.dart';
import '../models/audiobook.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import 'accent_colors.dart';
import 'tappable_text.dart';
import 'theme.dart';

/// Səsli kitab plyeri — dinlə + mətni oxu + naməlum sözə toxunub mənasına bax.
///
/// Vəziyyət native tərəfdən dövri olaraq (`_pollInterval`) oxunur; EventChannel
/// əvəzinə sorğu seçilib, çünki səth kiçik qalsın deyə (bax
/// `audio_player_service.dart`).
class AudiobookPlayerScreen extends StatefulWidget {
  const AudiobookPlayerScreen({
    super.key,
    required this.book,
    required this.initialIndex,
    required this.player,
    required this.sourceFor,
    required this.lookupWord,
    this.accent,
  });

  final Audiobook book;
  final int initialIndex;
  final AudioPlayer player;

  /// Fəsil → çalınacaq mənbə (URL və ya yerli fayl yolu).
  final String Function(Audiobook book, AudiobookChapter chapter) sourceFor;

  /// Toxunulan sözün mənasını gətirir (kontekst = sözün keçdiyi cümlə).
  final Future<WordLookupResult> Function(String word, String context)
      lookupWord;

  /// Xüsusiyyətin sabit aksent rəngi (bax `accent_colors.dart`). Null olsa
  /// mövcud neytral tema rəngləri işlədilir.
  final AccentColor? accent;

  @override
  State<AudiobookPlayerScreen> createState() => _AudiobookPlayerScreenState();
}

const _pollInterval = Duration(milliseconds: 100);
const _audiobookSyncLeadMs = 80;
const _skip = Duration(seconds: 10);

class _AudiobookPlayerScreenState extends State<AudiobookPlayerScreen> {
  late int _index;
  Timer? _poll;
  AudioPlaybackState _state = const AudioPlaybackState();
  bool _starting = true;
  String? _error;
  List<SongLine> _lines = const [];

  AudiobookChapter get _chapter => widget.book.chapters[_index];

  List<SongLine> _linesForChapter(AudiobookChapter chapter) {
    final duration = chapter.duration.inMilliseconds > 0
        ? chapter.duration
        : _state.duration;
    return buildAudiobookLines(chapter.text, duration);
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.book.chapters.length - 1);
    _start();
    _poll = Timer.periodic(_pollInterval, (_) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.player.stop();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
      _state = const AudioPlaybackState();
      _lines = _linesForChapter(_chapter);
    });
    try {
      await widget.player.play(widget.sourceFor(widget.book, _chapter));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Səs açılmadı — internetini yoxla.';
        _starting = false;
      });
    }
  }

  Future<void> _tick() async {
    if (!mounted) return;
    try {
      final s = await widget.player.state();
      if (!mounted) return;
      setState(() {
        _state = s;
        if (s.prepared) _starting = false;
        // Native xəta da göstərilir — səssiz uğursuzluq olmasın.
        if (s.error != null) _error = 'Səs xətası: ${s.error}';
        if (s.duration.inMilliseconds > 0 && _lines.isNotEmpty) {
          final rebuilt = _linesForChapter(_chapter);
          if (rebuilt.isNotEmpty) _lines = rebuilt;
        }
      });
      if (s.completed) _onCompleted();
    } catch (_) {
      // Növbəti sorğuda təkrar cəhd olunur.
    }
  }

  void _onCompleted() {
    if (_index < widget.book.chapters.length - 1) {
      _goto(_index + 1);
    }
  }

  void _goto(int index) {
    if (index < 0 || index >= widget.book.chapters.length) return;
    setState(() => _index = index);
    _start();
  }

  Future<void> _toggle() async {
    if (_state.playing) {
      await widget.player.pause();
    } else if (_state.completed) {
      await _start();
    } else {
      await widget.player.resume();
    }
    await _tick();
  }

  Future<void> _nudge(Duration delta) async {
    final target = _state.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _state.duration ? _state.duration : target);
    await widget.player.seek(clamped);
    await _tick();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Toxunulan sözün cümləsini tapır — AI-yə düzgün məna üçün ötürülür
  /// (məs. "bank" çay sahili/bank fərqi). Tapılmasa bütün fəsil mətni
  /// (qısaldılmış) ehtiyat kimi ötürülür.
  String _sentenceContaining(String text, String word) {
    final boundary = RegExp(
        r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    for (final s in sentences) {
      if (boundary.hasMatch(s)) return s.trim();
    }
    return text.length > 200 ? text.substring(0, 200) : text;
  }

  void _onTapWord(String word) {
    final sentence = _sentenceContaining(_chapter.text, word);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _WordLookupSheet(
        word: word,
        lookup: () => widget.lookupWord(word, sentence),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.titleAz),
        backgroundColor: widget.accent?.tint,
      ),
      body: Column(
        children: [
          if (_error != null)
            Material(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer)),
                    ),
                    TextButton(
                      onPressed: _start,
                      child: const Text('Təkrar'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.screen,
                    AppSpacing.screen,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_index + 1} / ${widget.book.chapters.length}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                      const SizedBox(height: 4),
                      Text(_chapter.titleEn,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Expanded(
                  child: _SyncedChapterText(
                    lines: _lines,
                    positionMs: _state.position.inMilliseconds,
                    syncLeadMs: _audiobookSyncLeadMs,
                    accent: widget.accent,
                    onTapWord: _onTapWord,
                  ),
                ),
              ],
            ),
          ),
          _Controls(
            state: _state,
            starting: _starting,
            positionLabel: _fmt(_state.position),
            durationLabel: _fmt(
                _state.duration == Duration.zero ? _chapter.duration : _state.duration),
            onSeek: (v) => widget.player.seek(
              Duration(milliseconds: (v * _state.duration.inMilliseconds).round()),
            ),
            onToggle: _toggle,
            onBack: () => _nudge(-_skip),
            onForward: () => _nudge(_skip),
            onPrev: _index > 0 ? () => _goto(_index - 1) : null,
            onNext: _index < widget.book.chapters.length - 1
                ? () => _goto(_index + 1)
                : null,
            accent: widget.accent,
          ),
        ],
      ),
    );
  }
}

/// Musiqi karaoke view-i ilə eyni UX — oxunmuş/aktiv/gələcək sözlər rənglənir.
class _SyncedChapterText extends StatefulWidget {
  const _SyncedChapterText({
    required this.lines,
    required this.positionMs,
    required this.syncLeadMs,
    required this.onTapWord,
    this.accent,
  });

  final List<SongLine> lines;
  final int positionMs;
  final int syncLeadMs;
  final void Function(String word) onTapWord;
  final AccentColor? accent;

  @override
  State<_SyncedChapterText> createState() => _SyncedChapterTextState();
}

class _SyncedChapterTextState extends State<_SyncedChapterText> {
  final _scroll = ScrollController();
  final _lineKeys = <GlobalKey>[];
  int _lastScrolledLine = -1;

  @override
  void initState() {
    super.initState();
    _syncLineKeys();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _syncLineKeys() {
    while (_lineKeys.length < widget.lines.length) {
      _lineKeys.add(GlobalKey());
    }
    if (_lineKeys.length > widget.lines.length) {
      _lineKeys.removeRange(widget.lines.length, _lineKeys.length);
    }
  }

  void _scrollToLine(int index) {
    if (index < 0 || index >= _lineKeys.length) return;
    final ctx = _lineKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.4,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  @override
  void didUpdateWidget(covariant _SyncedChapterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.length != widget.lines.length) {
      _syncLineKeys();
      _lastScrolledLine = -1;
    }
    final active = activeLineIndex(
      widget.lines,
      widget.positionMs,
      syncLeadMs: widget.syncLeadMs,
    );
    if (active >= 0 && active != _lastScrolledLine) {
      _lastScrolledLine = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToLine(active);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accent?.accent ?? theme.colorScheme.primary;
    final activeLine = activeLineIndex(
      widget.lines,
      widget.positionMs,
      syncLeadMs: widget.syncLeadMs,
    );
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.35);
    final pastColor = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.6);

    if (widget.lines.isEmpty) {
      return Center(
        key: const Key('chapter-text-empty'),
        child: Text(
          'Mətn yoxdur',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }

    return ListView.separated(
      key: const Key('chapter-text'),
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.screen),
      itemCount: widget.lines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final line = widget.lines[i];
        final isPast = activeLine >= 0 && i < activeLine;
        final isActive = i == activeLine;
        final activeWord = isActive
            ? activeWordIndex(
                line,
                widget.positionMs,
                syncLeadMs: widget.syncLeadMs,
              )
            : -1;

        return KeyedSubtree(
          key: _lineKeys[i],
          child: RichText(
            text: TextSpan(
              children: buildSyncedWordSpans(
                text: line.text,
                baseStyle: baseStyle,
                onTapWord: widget.onTapWord,
                styleForWord: (wordIdx) {
                  if (isPast) {
                    return baseStyle?.copyWith(color: pastColor);
                  }
                  if (!isActive) {
                    return baseStyle?.copyWith(color: muted);
                  }
                  if (wordIdx < activeWord) {
                    return baseStyle?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w500,
                    );
                  }
                  if (wordIdx == activeWord) {
                    return baseStyle?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      backgroundColor: accent.withValues(alpha: 0.18),
                    );
                  }
                  return baseStyle?.copyWith(color: muted);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.starting,
    required this.positionLabel,
    required this.durationLabel,
    required this.onSeek,
    required this.onToggle,
    required this.onBack,
    required this.onForward,
    this.onPrev,
    this.onNext,
    this.accent,
  });

  final AudioPlaybackState state;
  final bool starting;
  final String positionLabel;
  final String durationLabel;
  final ValueChanged<double> onSeek;
  final VoidCallback onToggle;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final AccentColor? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: state.progress,
                onChanged: state.prepared ? onSeek : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(positionLabel, style: theme.textTheme.bodySmall),
                    Text(durationLabel, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: onPrev,
                    icon: const Icon(Icons.skip_previous),
                    tooltip: 'Əvvəlki hekayə',
                  ),
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.replay_10),
                    tooltip: '10 saniyə geri',
                  ),
                  starting
                      ? const SizedBox(
                          width: 56,
                          height: 56,
                          child: Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.6),
                            ),
                          ),
                        )
                      : IconButton.filled(
                          iconSize: 34,
                          onPressed: onToggle,
                          style: accent == null
                              ? null
                              : IconButton.styleFrom(
                                  backgroundColor: accent!.accent,
                                  foregroundColor: accent!.onAccent,
                                ),
                          icon: Icon(state.playing
                              ? Icons.pause
                              : Icons.play_arrow),
                          tooltip: state.playing ? 'Dayandır' : 'Çal',
                        ),
                  IconButton(
                    onPressed: onForward,
                    icon: const Icon(Icons.forward_10),
                    tooltip: '10 saniyə irəli',
                  ),
                  IconButton(
                    onPressed: onNext,
                    icon: const Icon(Icons.skip_next),
                    tooltip: 'Növbəti hekayə',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toxunulan sözün mənasını göstərən aşağı vərəq — özünü idarə edir
/// (yüklənir/nəticə/xəta), ana ekranın vəziyyətinə bağlı deyil.
class _WordLookupSheet extends StatefulWidget {
  const _WordLookupSheet({required this.word, required this.lookup});

  final String word;
  final Future<WordLookupResult> Function() lookup;

  @override
  State<_WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends State<_WordLookupSheet> {
  bool _loading = true;
  WordLookupResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.lookup();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.word,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null) ...[
              Text('Tapılmadı: ${_error!}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Yenidən cəhd et'),
              ),
            ] else ...[
              Text(_result!.ipa,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 4),
              Text(_result!.translationAz, style: theme.textTheme.titleLarge),
            ],
          ],
        ),
      ),
    );
  }
}
