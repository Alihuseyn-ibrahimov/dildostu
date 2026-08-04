import 'package:flutter/material.dart';

import '../data/review_repository.dart';
import '../models/word.dart';
import '../services/speaker.dart';
import 'accent_colors.dart';
import 'word_card_view.dart';

/// Sessiyada göstəriləcək bir söz — `wordKey` ReviewRepository-də unikal
/// identifikator kimi işlədilir (adətən "packId:word").
class SessionEntry {
  const SessionEntry({required this.wordKey, required this.word});

  final String wordKey;
  final Word word;
}

/// Söz siyahısını bir-bir kart kimi gəzdirən sessiya (adi paket kartları
/// və axşam təkrarı eyni bu ekranı işlədir). Hər cavab ReviewRepository-yə
/// ReviewEngine vasitəsilə yazılır.
class CardSessionScreen extends StatefulWidget {
  const CardSessionScreen({
    super.key,
    required this.title,
    required this.entries,
    required this.speaker,
    required this.reviewRepository,
    this.accent,
  });

  final String title;
  final List<SessionEntry> entries;
  final Speaker speaker;
  final ReviewRepository reviewRepository;

  /// Paketin sabit aksent rəngi (bax `accent_colors.dart`). Yalnız TƏK
  /// paketdən açılan sessiyada verilir (manual seçim) — qarışıq paketli
  /// sessiyada (Axşam təkrarı) `null` qalır.
  final AccentColor? accent;

  @override
  State<CardSessionScreen> createState() => _CardSessionScreenState();
}

class _CardSessionScreenState extends State<CardSessionScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    widget.speaker.stop();
    super.dispose();
  }

  void _handleReview(ReviewOutcome outcome) {
    widget.reviewRepository.recordReview(
      widget.entries[_index].wordKey,
      outcome,
      now: DateTime.now(),
    );

    final isLast = _index >= widget.entries.length - 1;
    if (isLast) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.accent?.tint,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: entries.isEmpty ? 0 : (_index + 1) / entries.length,
          ),
        ),
      ),
      body: entries.isEmpty
          ? const Center(child: Text('Bu siyahıda söz yoxdur.'))
          : PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: entries.length,
              itemBuilder: (context, i) => WordCardView(
                word: entries[i].word,
                speaker: widget.speaker,
                onReview: _handleReview,
                accent: widget.accent,
              ),
            ),
    );
  }
}
