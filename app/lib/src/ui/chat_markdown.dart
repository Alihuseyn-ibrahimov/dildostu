import 'package:flutter/material.dart';

/// AI cavabları üçün yüngül markdown renderi.
///
/// Tam markdown paketi qəsdən əlavə edilmir (bax `CLAUDE.md` — əlavə plugin
/// Gradle riski). AI real olaraq yalnız bu üç şeyi işlədir: `**qalın**`,
/// `- madde` / `1. madde` siyahıları və boş sətirlə ayrılmış abzaslar.
class ChatMarkdown extends StatelessWidget {
  const ChatMarkdown({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  static final _bold = RegExp(r'\*\*(.+?)\*\*');
  static final _bullet = RegExp(r'^\s*[-*•]\s+');
  static final _numbered = RegExp(r'^\s*(\d+)[.)]\s+');

  /// `**qalın**` hissələri ayrı span-a bölür (qalanı adi mətn).
  static List<TextSpan> spansFor(String line, TextStyle style) {
    final spans = <TextSpan>[];
    var index = 0;
    for (final match in _bold.allMatches(line)) {
      if (match.start > index) {
        spans.add(TextSpan(text: line.substring(index, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      index = match.end;
    }
    if (index < line.length) {
      spans.add(TextSpan(text: line.substring(index)));
    }
    return spans.isEmpty ? [TextSpan(text: line)] : spans;
  }

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final blocks = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 8));
        continue;
      }

      final bulletMatch = _bullet.firstMatch(line);
      final numberedMatch = _numbered.firstMatch(line);
      if (bulletMatch != null || numberedMatch != null) {
        final marker = numberedMatch != null ? '${numberedMatch.group(1)}.' : '•';
        final content = line.substring(
            (bulletMatch ?? numberedMatch)!.end);
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(marker,
                    style: style.copyWith(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: spansFor(content, style)),
                  style: style,
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text.rich(
          TextSpan(children: spansFor(line, style)),
          style: style,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }
}
