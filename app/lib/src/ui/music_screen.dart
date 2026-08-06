import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../data/word_lookup_client.dart';
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
    this.accent,
  });

  final Future<List<Song>> Function() loader;
  final void Function(Song song) onOpenSong;
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
      setState(() {
        _error = 'Musiqi kataloqu yüklənmədi — internetini yoxla.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Musiqi'),
        backgroundColor: widget.accent?.tint,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : (songs == null || songs.isEmpty)
                  ? const Center(child: Text('Hələ mahnı yoxdur.'))
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

/// Bir mahnının pleyeri — video (embed) + sətir-sətir sözlər (hər sətrin
/// altında AZ tərcüməsi), sözə toxunub ayrıca mənasına bax.
///
/// Video tarixçəsi (2026-08-05, real cihazda sınandıqca üç mərhələ):
/// 1. `youtube_player_iframe` (`loadHtmlString` + saxta `baseUrl`) —
///    WebView bu `baseUrl`-i FAKTİKİ tətbiq etmirdi (səhifə `data:` origin-lə
///    açılırdı), YouTube "Video pleyer konfiqurasiya xətası" göstərirdi.
/// 2. Statik eskiz + toxunanda xarici keçid (`url_launcher`
///    `inAppBrowserView`, Custom Tabs) — Android-in App Links mexanizmi
///    HƏR youtube.com keçidini (Custom Tabs daxil) YouTube tətbiqinə
///    yönləndirirdi, istifadəçi "app-dan çıxdı" dedi.
/// 3. **HƏLL:** `youtube.com`-a BİRBAŞA getmək əvəzinə, öz serverimizdəki
///    `/music/embed/{id}` səhifəsini yükləyirik (`dildostu_server/app.py`,
///    `music_embed`) — bu, HƏQİQİ https origin verir (App Links youtube.com-a
///    aid olduğu üçün bizim domenimizi tutmur) VƏ YouTube-un iframe-i
///    normal (səhifə→youtube.com) origin-lə işləyir, "data:" xətası olmur.
///
/// Video-lyrics sinxronlaşması YOXDUR (V1) — istifadəçi özü scroll edir
/// (bax spec: docs/superpowers/specs/2026-08-05-dildostu-music-section-design.md).
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

  /// Video ID → bizim serverdəki embed səhifəsinin tam URL-i (main.dart-da
  /// `AppConfig.serverBaseUrl`-ə bağlanır, bax `audiobook_client.dart`-dakı
  /// `chapterUrl` nümunəsi — ekran özü server ünvanından xəbərsiz qalır).
  final String Function(String videoId) embedUrlFor;

  final AccentColor? accent;

  @override
  State<SongPlayerScreen> createState() => _SongPlayerScreenState();
}

class _SongPlayerScreenState extends State<SongPlayerScreen> {
  late final WebViewController _webView;

  @override
  void initState() {
    super.initState();
    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.embedUrlFor(widget.song.youtubeId)));
    // Android WebView-də üçüncü tərəf cookie-lər defolt söndürülüb —
    // YouTube-un pleyeri bunlarsız işləməyə bilər.
    final platform = _webView.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewCookieManager(const PlatformWebViewCookieManagerCreationParams())
          .setAcceptThirdPartyCookies(platform, true);
    }
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
            child: SongLyricsView(
              lines: widget.song.lines,
              lookupWord: widget.lookupWord,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sətir-sətir lyrics + sözə toxunub mənasına bax — `WebViewController`-dan
/// (webview platform mock tələb edir) qəsdən AYRI widget ki, video olmadan
/// da test oluna bilsin (bax dildostu/CLAUDE.md-dəki webview test
/// məhdudiyyəti, 2026-08-05 tapıntısı).
class SongLyricsView extends StatelessWidget {
  const SongLyricsView({super.key, required this.lines, required this.lookupWord});

  final List<SongLine> lines;

  /// Toxunulan sözün mənasını gətirir (kontekst = sözün keçdiyi sətir).
  final Future<WordLookupResult> Function(String word, String context)
      lookupWord;

  void _onTapWord(BuildContext context, SongLine line, String word) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _WordLookupSheet(
        word: word,
        lookup: () => lookupWord(word, line.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      key: const Key('song-lyrics'),
      padding: const EdgeInsets.all(AppSpacing.screen),
      itemCount: lines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final line = lines[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: buildTappableWordSpans(
                  text: line.text,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(height: 1.4, color: theme.colorScheme.onSurface),
                  onTapWord: (word) => _onTapWord(context, line, word),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(line.translationAz,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        );
      },
    );
  }
}

/// Toxunulan sözün mənasını göstərən aşağı vərəq — `audiobook_player_screen.dart`-
/// dakı `_WordLookupSheet`-in eynidir (özünü idarə edir, ana ekranın
/// vəziyyətindən asılı deyil).
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
