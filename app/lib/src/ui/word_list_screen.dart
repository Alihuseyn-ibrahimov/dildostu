import 'package:flutter/material.dart';

import '../models/live_message.dart';
import 'accent_colors.dart';
import 'theme.dart';

/// Bir paketin söz siyahısı — hər sətir söz + tərcümə; toxunanda həmin sözün
/// ətraflı ekranı açılır (indeks ötürülür ki, orada irəli/geri keçid işləsin).
///
/// `loader` inject olunur (main.dart-da LiveContentClient.packWords-ə bağlanır)
/// → ekran HTTP-dən asılı deyil, fake loader ilə test olunur.
class WordListScreen extends StatefulWidget {
  const WordListScreen({
    super.key,
    required this.title,
    required this.loader,
    required this.onOpenWord,
    this.accent,
  });

  final String title;
  final Future<List<LiveMessage>> Function() loader;

  /// Siyahıdan sözə keçid: bütün siyahı + seçilən indeks.
  final void Function(List<LiveMessage> words, int index) onOpenWord;

  /// Paketin sabit aksent rəngi (bax `accent_colors.dart`). Null olsa
  /// mövcud neytral tema rəngləri işlədilir.
  final AccentColor? accent;

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  List<LiveMessage>? _words;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final words = await widget.loader();
    if (!mounted) return;
    setState(() {
      _words = words;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = _words;
    final accent = widget.accent;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: accent?.tint,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (words == null || words.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.screen),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Bu paketdə söz tapılmadı.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Yenidən cəhd et'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screen, vertical: 12),
                  itemCount: words.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final w = words[i];
                    return Card(
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusCard),
                        onTap: () => widget.onOpenWord(words, i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              // Sıra nömrəsi — istifadəçi harada olduğunu bilsin.
                              SizedBox(
                                width: 28,
                                child: Text('${i + 1}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: accent?.accent ??
                                            theme.colorScheme.outline)),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(w.word,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(w.translationAz,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                color: theme
                                                    .colorScheme.outline)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: accent?.accent ??
                                      theme.colorScheme.outlineVariant),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
