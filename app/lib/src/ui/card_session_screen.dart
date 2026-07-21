import 'package:flutter/material.dart';

import '../models/pack.dart';
import '../services/speaker.dart';
import 'word_card_view.dart';

/// Bir paketin sözlərini bir-bir kart kimi gəzdirən sessiya.
/// Phase 3-də `onReview` ReviewEngine-ə bağlanacaq; hazırda sadəcə irəliləyir.
class CardSessionScreen extends StatefulWidget {
  const CardSessionScreen({
    super.key,
    required this.pack,
    required this.speaker,
  });

  final Pack pack;
  final Speaker speaker;

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

  void _handleReview(ReviewOutcome _) {
    final isLast = _index >= widget.pack.words.length - 1;
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
    final words = widget.pack.words;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pack.titleAz),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: words.isEmpty ? 0 : (_index + 1) / words.length,
          ),
        ),
      ),
      body: words.isEmpty
          ? const Center(child: Text('Bu paketdə söz yoxdur.'))
          : PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: words.length,
              itemBuilder: (context, i) => WordCardView(
                word: words[i],
                speaker: widget.speaker,
                onReview: _handleReview,
              ),
            ),
    );
  }
}
