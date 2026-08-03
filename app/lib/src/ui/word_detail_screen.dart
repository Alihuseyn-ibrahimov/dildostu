import 'package:flutter/material.dart';

import '../models/live_message.dart';
import '../models/user_profile.dart';
import '../services/speaker.dart';
import 'theme.dart';

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
  });

  final String title;
  final List<LiveMessage> words;
  final Speaker speaker;
  final int initialIndex;

  /// "Sual ver" — AI söhbətini bu kontekstlə açır (main.dart bağlayır).
  final VoidCallback? onAskQuestion;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, _lastIndex);
    _controller = PageController(initialPage: _index);
  }

  int get _lastIndex => widget.words.isEmpty ? 0 : widget.words.length - 1;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('Söz yoxdur.')),
      );
    }

    final current = widget.words[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
              },
              itemCount: widget.words.length,
              itemBuilder: (context, i) => _WordDetailBody(
                message: widget.words[i],
                onSpeak: () => widget.speaker.speak(widget.words[i].word),
              ),
            ),
          ),
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
                    child: Text('${_index + 1}/${widget.words.length}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _index < _lastIndex ? () => _goTo(_index + 1) : null,
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
  const _WordDetailBody({required this.message, required this.onSpeak});

  final LiveMessage message;
  final VoidCallback onSpeak;

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
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            ),
            child: Row(
              children: [
                const Text('🤖  '),
                Expanded(
                  child: Text(message.aiLine,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer)),
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
          const SizedBox(height: AppSpacing.section),
          FilledButton.tonalIcon(
            onPressed: onSpeak,
            icon: const Icon(Icons.volume_up),
            label: const Text('Səsləndir'),
          ),
        ],
      ),
    );
  }
}
