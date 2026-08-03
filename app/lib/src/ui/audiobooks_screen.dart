import 'package:flutter/material.dart';

import '../models/audiobook.dart';
import 'theme.dart';

/// Səsli kitab kitabxanası — kitab siyahısı.
///
/// `loader` inject olunur (main.dart-da AudiobookClient-ə bağlanır) → ekran
/// HTTP-dən asılı deyil, saxta loader ilə test olunur.
class AudiobooksScreen extends StatefulWidget {
  const AudiobooksScreen({
    super.key,
    required this.loader,
    required this.onOpenBook,
  });

  final Future<List<Audiobook>> Function() loader;
  final void Function(Audiobook book) onOpenBook;

  @override
  State<AudiobooksScreen> createState() => _AudiobooksScreenState();
}

class _AudiobooksScreenState extends State<AudiobooksScreen> {
  List<Audiobook>? _books;
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
      final books = await widget.loader();
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Səssiz boş ekran YOX — səbəb göstərilir (bax CLAUDE.md dərsi).
      setState(() {
        _error = 'Kitabxana yüklənmədi — internetini yoxla.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = _books;
    return Scaffold(
      appBar: AppBar(title: const Text('Səsli kitablar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : (books == null || books.isEmpty)
                  ? const Center(child: Text('Hələ kitab yoxdur.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      itemCount: books.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _BookCard(
                        book: books[i],
                        onTap: () => widget.onOpenBook(books[i]),
                      ),
                    ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap});

  final Audiobook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = book.totalDuration.inMinutes / 60;
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
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                ),
                child: Icon(Icons.headphones,
                    color: theme.colorScheme.onSecondaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.titleAz,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${book.chapters.length} hekayə · '
                      '${hours < 1 ? "${book.totalDuration.inMinutes} dəq" : "${hours.toStringAsFixed(1)} saat"}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 2),
                    // Attribution — ictimai domen mənbəyi həmişə görünür.
                    Text(book.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outlineVariant)),
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

/// Bir kitabın fəsil (hekayə) siyahısı.
class AudiobookChaptersScreen extends StatelessWidget {
  const AudiobookChaptersScreen({
    super.key,
    required this.book,
    required this.onOpenChapter,
  });

  final Audiobook book;
  final void Function(int index) onOpenChapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(book.titleAz)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen, vertical: 12),
        itemCount: book.chapters.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final ch = book.chapters[i];
          return Card(
            child: ListTile(
              leading: SizedBox(
                width: 32,
                child: Text('${i + 1}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
              title: Text(ch.titleEn),
              subtitle: Text(ch.durationLabel),
              trailing: const Icon(Icons.play_circle_outline),
              onTap: () => onOpenChapter(i),
            ),
          );
        },
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
