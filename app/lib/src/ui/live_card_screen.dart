import 'package:flutter/material.dart';

import '../models/live_message.dart';
import '../models/user_profile.dart';
import '../services/speaker.dart';

/// Sözün çətinlik səviyyəsini göstərən kiçik nişan (spec §4).
class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  /// `LiveMessage.level` — 1-3.
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = ProficiencyLevel.values
        .where((l) => l.wordLevel == level)
        .firstOrNull;
    if (match == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(match.labelAz,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

/// Canlı AI mesajını göstərən kart: AI-nin dostcasına sətri + söz/IPA/tərcümə/
/// nümunə + səsləndir + sürətli düymələr ("başqa nümunə/sadələşdir/çətinləşdir").
///
/// `fetch(mode)` çağırışı LiveContentClient-ə bağlanır (main.dart-da); ekran
/// birbaşa HTTP-dən asılı deyil, ona görə fake fetcher ilə test olunur.
class LiveCardScreen extends StatefulWidget {
  const LiveCardScreen({
    super.key,
    required this.title,
    required this.speaker,
    required this.fetch,
    this.onAskQuestion,
  });

  final String title;
  final Speaker speaker;
  final Future<LiveMessage> Function(String mode) fetch;

  /// "Sual ver" düyməsi — AI söhbətini bu kontekstlə açır (main.dart bağlayır).
  final VoidCallback? onAskQuestion;

  @override
  State<LiveCardScreen> createState() => _LiveCardScreenState();
}

class _LiveCardScreenState extends State<LiveCardScreen> {
  LiveMessage? _message;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load('normal');
  }

  Future<void> _load(String mode) async {
    setState(() => _loading = true);
    final msg = await widget.fetch(mode);
    if (!mounted) return;
    setState(() {
      _message = msg;
      _loading = false;
    });
  }

  @override
  void dispose() {
    widget.speaker.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = _message;
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
          if (msg != null && !msg.isLive)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Offline rejim (statik)',
                child: Icon(Icons.cloud_off, size: 20),
              ),
            ),
        ],
      ),
      body: _loading || msg == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // AI-nin dostcasına sətri
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Text('🤖  '),
                        Expanded(
                          child: Text(msg.aiLine,
                              style: theme.textTheme.titleMedium),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(child: _LevelChip(level: msg.level)),
                  const SizedBox(height: 14),
                  Text(msg.word,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(msg.ipa,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 14),
                  Text(msg.translationAz,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(msg.example, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(msg.exampleAz,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: () => widget.speaker.speak(msg.word),
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Səsləndir'),
                  ),
                  const Spacer(),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _load('another_example'),
                        child: const Text('Başqa nümunə'),
                      ),
                      OutlinedButton(
                        onPressed: () => _load('simpler'),
                        child: const Text('Sadələşdir'),
                      ),
                      OutlinedButton(
                        onPressed: () => _load('harder'),
                        child: const Text('Çətinləşdir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
