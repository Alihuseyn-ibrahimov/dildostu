import 'package:dildostu/src/ui/chat_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 14);

Future<void> _pump(WidgetTester tester, String text) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatMarkdown(text: text, style: _style)),
      ),
    );

void main() {
  group('spansFor', () {
    test('qalın hissəni ayrı span edir', () {
      final spans = ChatMarkdown.spansFor('Salam **dünya**!', _style);
      expect(spans.map((s) => s.text), ['Salam ', 'dünya', '!']);
      expect(spans[1].style?.fontWeight, FontWeight.bold);
      expect(spans[0].style?.fontWeight, isNull);
    });

    test('qalın olmayan mətni bütöv saxlayır', () {
      final spans = ChatMarkdown.spansFor('adi mətn', _style);
      expect(spans.single.text, 'adi mətn');
    });

    test('bir sətirdə bir neçə qalın hissəni tanıyır', () {
      final spans = ChatMarkdown.spansFor('**bir** və **iki**', _style);
      final bold = spans.where((s) => s.style?.fontWeight == FontWeight.bold);
      expect(bold.map((s) => s.text), ['bir', 'iki']);
    });

    test('boş mətndə boş siyahı qaytarmır', () {
      expect(ChatMarkdown.spansFor('', _style), hasLength(1));
    });
  });

  group('render', () {
    testWidgets('ulduz işarələri ekranda görünmür', (tester) async {
      await _pump(tester, 'Bu **vacibdir**.');
      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('vacibdir'), findsOneWidget);
    });

    testWidgets('tire siyahısı bullet işarəsi ilə göstərilir', (tester) async {
      await _pump(tester, '- birinci\n- ikinci');
      expect(find.text('•'), findsNWidgets(2));
      expect(find.textContaining('birinci'), findsOneWidget);
      expect(find.textContaining('ikinci'), findsOneWidget);
    });

    testWidgets('nömrəli siyahı öz nömrəsini saxlayır', (tester) async {
      await _pump(tester, '1. birinci\n2. ikinci');
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
    });

    testWidgets('adi çoxsətirli mətn hər sətri göstərir', (tester) async {
      await _pump(tester, 'birinci sətir\n\nikinci sətir');
      expect(find.textContaining('birinci sətir'), findsOneWidget);
      expect(find.textContaining('ikinci sətir'), findsOneWidget);
    });
  });
}
