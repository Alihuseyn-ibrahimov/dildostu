import 'package:flutter/material.dart';

import '../models/live_message.dart';
import 'theme.dart';

typedef EssentialWordsLoader = Future<
    ({
      List<LiveMessage> words,
      int total,
      int nextOffset,
    })> Function(int offset);

/// "Əsas lüğət" — 504 sabit söz bankından səviyyəyə uyğun dəst, "Növbəti
/// sözlər" düyməsi ilə bank boyu dövr edir (spec: konteksdən asılı olmayan
/// ümumi lüğət, bax `essential_words.py`).
///
/// `loader` inject olunur (main.dart-da LiveContentClient.essentialWords-ə
/// bağlanır) → ekran HTTP-dən asılı deyil, fake loader ilə test olunur.
class EssentialWordsScreen extends StatefulWidget {
  const EssentialWordsScreen({
    super.key,
    required this.loader,
    required this.onOpenWord,
  });

  final EssentialWordsLoader loader;

  /// Siyahıdan sözə keçid: bütün siyahı + seçilən indeks.
  final void Function(List<LiveMessage> words, int index) onOpenWord;

  @override
  State<EssentialWordsScreen> createState() => _EssentialWordsScreenState();
}

class _EssentialWordsScreenState extends State<EssentialWordsScreen> {
  List<LiveMessage>? _words;
  int _offset = 0;
  int _nextOffset = 0;
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  Future<void> _load(int offset) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.loader(offset);
      if (!mounted) return;
      setState(() {
        _words = result.words;
        _total = result.total;
        _nextOffset = result.nextOffset;
        _offset = offset;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Yüklənmədi — internetini yoxla.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = _words;

    return Scaffold(
      appBar: AppBar(title: const Text('Əsas lüğət')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: () => _load(_offset))
              : Column(
                  children: [
                    if (_total > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screen, 12, AppSpacing.screen, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_offset + 1}-${_offset + (words?.length ?? 0)} / $_total söz',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ),
                      ),
                    Expanded(
                      child: (words == null || words.isEmpty)
                          ? const Center(child: Text('Söz tapılmadı.'))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.screen, vertical: 12),
                              itemCount: words.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) => _WordRow(
                                index: i,
                                message: words[i],
                                onTap: () => widget.onOpenWord(words, i),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _load(_nextOffset),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Növbəti sözlər'),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.index,
    required this.message,
    required this.onTap,
  });

  final int index;
  final LiveMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('${index + 1}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message.word,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(message.translationAz,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.outlineVariant),
            ],
          ),
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
