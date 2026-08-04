import 'dart:async';

import 'package:flutter/material.dart';

import '../data/word_lookup_client.dart';
import '../models/audiobook.dart';
import '../services/audio_player_service.dart';
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
  });

  final Audiobook book;
  final int initialIndex;
  final AudioPlayer player;

  /// Fəsil → çalınacaq mənbə (URL və ya yerli fayl yolu).
  final String Function(Audiobook book, AudiobookChapter chapter) sourceFor;

  /// Toxunulan sözün mənasını gətirir (kontekst = sözün keçdiyi cümlə).
  final Future<WordLookupResult> Function(String word, String context)
      lookupWord;

  @override
  State<AudiobookPlayerScreen> createState() => _AudiobookPlayerScreenState();
}

const _pollInterval = Duration(milliseconds: 400);
const _skip = Duration(seconds: 10);

class _AudiobookPlayerScreenState extends State<AudiobookPlayerScreen> {
  late int _index;
  Timer? _poll;
  AudioPlaybackState _state = const AudioPlaybackState();
  bool _starting = true;
  String? _error;

  AudiobookChapter get _chapter => widget.book.chapters[_index];

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
      appBar: AppBar(title: Text(widget.book.titleAz)),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screen),
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
                  const SizedBox(height: 16),
                  RichText(
                    key: const Key('chapter-text'),
                    text: TextSpan(
                      children: buildTappableWordSpans(
                        text: _chapter.text,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(height: 1.6, color: theme.colorScheme.onSurface),
                        onTapWord: _onTapWord,
                      ),
                    ),
                  ),
                ],
              ),
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
          ),
        ],
      ),
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
