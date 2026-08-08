import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../data/word_lookup_client.dart';
import '../engine/lyrics_sync.dart';
import '../models/song.dart';
import 'accent_colors.dart';
import 'tappable_text.dart';
import 'theme.dart';

/// Musiqi kitabxanası — mahnı siyahısı.
///
/// `loader` inject olunur (main.dart-da MusicClient-ə bağlanır) — ekran
/// HTTP-dən asılı deyil, saxta loader ilə test olunur. Struktur
/// `AudiobooksScreen`-in eynidir (bax audiobooks_screen.dart).
class MusicScreen extends StatefulWidget {
  const MusicScreen({
    super.key,
    required this.loader,
    required this.onOpenSong,
    this.levelLabel,
    this.accent,
  });

  final Future<List<Song>> Function() loader;
  final void Function(Song song) onOpenSong;

  /// Cari çətinlik səviyyəsi (məs. "Asan") — AppBar alt başlığı.
  final String? levelLabel;
  final AccentColor? accent;

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  List<Song>? _songs;
  bool _loading = true;
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
      final songs = await widget.loader();
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Səssiz boş ekran YOX — səbəb göstərilir (bax CLAUDE.md dərsi).
      // Musiqi videosu YouTube-dan canlı axır (offline saxlanmır — bax
      // dildostu/CLAUDE.md hüquqi məhdudiyyət), ona görə bu bölmə həmişə
      // internet tələb edir; digər bölmələr (lüğət, səsli kitablar)
      // endirildikdən sonra offline işləyir.
      setState(() {
        _error = 'Musiqi üçün internet lazımdır — qoşulub yenidən cəhd et.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songs = _songs;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Musiqi'),
            if (widget.levelLabel != null)
              Text(
                '${widget.levelLabel!} səviyyə',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
          ],
        ),
        backgroundColor: widget.accent?.tint,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : (songs == null || songs.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.screen),
                        child: Text(
                          widget.levelLabel != null
                              ? '${widget.levelLabel!} səviyyədə hələ mahnı yoxdur.'
                              : 'Hələ mahnı yoxdur.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      itemCount: songs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _SongCard(
                        song: songs[i],
                        onTap: () => widget.onOpenSong(songs[i]),
                        accent: widget.accent,
                      ),
                    ),
    );
  }
}

const _levelLabels = {
  'beginner': 'Asan',
  'intermediate': 'Orta',
  'advanced': 'Çətin',
};

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, required this.onTap, this.accent});

  final Song song;
  final VoidCallback onTap;
  final AccentColor? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent?.tint ?? theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                ),
                child: Icon(Icons.music_note,
                    color: accent?.accent ??
                        theme.colorScheme.onSecondaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} · ${_levelLabels[song.level] ?? song.level}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir mahnının pleyeri — video (embed) + sinxron sözlər.
///
/// YouTube IFrame API-dən vaxt oxunur (`/music/embed/{id}` səhifəsi),
/// sözlər oxunma vaxtına görə rənglənir (bax `lyrics_sync.dart`).
class SongPlayerScreen extends StatefulWidget {
  const SongPlayerScreen({
    super.key,
    required this.song,
    required this.lookupWord,
    required this.embedUrlFor,
    this.accent,
  });

  final Song song;

  /// Toxunulan sözün mənasını gətirir (kontekst = sözün keçdiyi sətir).
  final Future<WordLookupResult> Function(String word, String context)
      lookupWord;

  /// Video ID → bizim serverdəki embed səhifəsinin tam URL-i.
  final String Function(String videoId) embedUrlFor;

  final AccentColor? accent;

  @override
  State<SongPlayerScreen> createState() => _SongPlayerScreenState();
}

class _SongPlayerScreenState extends State<SongPlayerScreen> {
  late final WebViewController _webView;
  Timer? _syncTimeout;
  int _positionMs = 0;
  bool _syncWorking = false;
  bool _showSyncWarning = false;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'LyricsSync',
        onMessageReceived: (JavaScriptMessage message) {
          if (!mounted) return;
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            final pos = (data['pos'] as num?)?.toInt() ?? 0;
            final dur = (data['dur'] as num?)?.toInt() ?? 0;
            setState(() {
              _positionMs = pos;
              if (dur > 0) _syncWorking = true;
            });
          } catch (_) {}
        },
      )
      ..loadRequest(Uri.parse(widget.embedUrlFor(widget.song.youtubeId)));
    final platform = _webView.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewCookieManager(const PlatformWebViewCookieManagerCreationParams())
          .setAcceptThirdPartyCookies(platform, true);
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    _syncTimeout = Timer(const Duration(seconds: 5), () {
      if (mounted && !_syncWorking) {
        setState(() => _showSyncWarning = true);
      }
    });
  }

  @override
  void dispose() {
    _syncTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
        backgroundColor: widget.accent?.tint,
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: _webView),
          ),
          Expanded(
            child: Column(
              children: [
                if (_showSyncWarning)
                  Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screen, vertical: 8),
                      child: Text(
                        'Sinxron işləmir — video vaxtı oxunmur. '
                        'İnternetini yoxla (musiqi offline işləmir) '
                        'və ya server yenilənməlidir.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                      ),
                    ),
                  ),
                Expanded(
                  child: SongLyricsView(
                    lines: widget.song.lines,
                    lookupWord: widget.lookupWord,
                    positionMs: _positionMs,
                    accent: widget.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sətir-sətir lyrics + sinxron söz vurğulaması + sözə toxunub mənasına bax.
///
/// `WebViewController`-dan (webview platform mock tələb edir) qəsdən AYRI
/// widget ki, video olmadan da test oluna bilsin.
class SongLyricsView extends StatefulWidget {
  const SongLyricsView({
    super.key,
    required this.lines,
    required this.lookupWord,
    this.positionMs = 0,
    this.accent,
    this.syncLeadMs = kDefaultSyncLeadMs,
  });

  final List<SongLine> lines;
  final Future<WordLookupResult> Function(String word, String context)
      lookupWord;

  final int positionMs;
  final AccentColor? accent;
  final int syncLeadMs;

  @override
  State<SongLyricsView> createState() => _SongLyricsViewState();
}

class _SongLyricsViewState extends State<SongLyricsView> {
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

  /// Aktiv sətri videonun ALTINDAKI görünən sahədə saxlayır.
  ///
  /// Köhnə `(indeks × 72)` yanaşması sətri siyahının ən yuxarısına çəkirdi —
  /// istifadəçi oxunan sətri görə bilmirdi. İndi sətir viewport-un ortasına
  /// yaxın (~40%) gətirilir ki, həm yuxarıdakı, həm aşağıdakı kontekst görünsün.
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
  void didUpdateWidget(covariant SongLyricsView oldWidget) {
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

  void _onTapWord(BuildContext context, SongLine line, String word) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _WordLookupSheet(
        word: word,
        lookup: () => widget.lookupWord(word, line.text),
      ),
    );
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

    return ListView.separated(
      key: const Key('song-lyrics'),
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

        final muted = theme.colorScheme.onSurface.withValues(alpha: 0.35);
        final pastColor = theme.colorScheme.onSurface.withValues(alpha: 0.65);
        final baseStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.4);

        return KeyedSubtree(
          key: _lineKeys[i],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
              text: TextSpan(
                children: buildSyncedWordSpans(
                  text: line.text,
                  baseStyle: baseStyle,
                  onTapWord: (word) => _onTapWord(context, line, word),
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
            const SizedBox(height: 2),
            Text(
              line.translationAz,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isActive
                    ? accent
                    : isPast
                        ? pastColor
                        : theme.colorScheme.outline,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
          ),
        );
      },
    );
  }
}

/// Toxunulan sözün mənasını göstərən aşağı vərəq.
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yenidən cəhd et'),
            ),
          ],
        ),
      ),
    );
  }
}
