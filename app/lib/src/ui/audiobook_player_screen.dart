import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audiobook.dart';
import '../services/audio_player_service.dart';
import 'theme.dart';

/// Səsli kitab plyeri — dinlə + mətni oxu.
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
  });

  final Audiobook book;
  final int initialIndex;
  final AudioPlayer player;

  /// Fəsil → çalınacaq mənbə (URL və ya yerli fayl yolu).
  final String Function(Audiobook book, AudiobookChapter chapter) sourceFor;

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
                  SelectableText(
                    _chapter.text,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
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
