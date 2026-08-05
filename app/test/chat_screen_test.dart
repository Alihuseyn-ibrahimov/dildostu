import 'package:dildostu/src/models/chat_message.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mesaj göndər → user baloncuğu + AI cavabı', (tester) async {
    List<ChatMessage>? received;
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        sender: (history) async {
          received = history;
          return 'Salam! Necə kömək edim?';
        },
      ),
    ));

    await tester.enterText(find.byType(TextField), 'çayı necə deyim?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // İstifadəçi mesajı və AI cavabı görünür
    expect(find.text('çayı necə deyim?'), findsOneWidget);
    expect(find.text('Salam! Necə kömək edim?'), findsOneWidget);
    // sender bütün tarixçəni aldı (bu halda 1 user mesajı)
    expect(received!.last.content, 'çayı necə deyim?');
    expect(received!.last.role, ChatRole.user);
  });

  testWidgets('greeting varsa ilk AI mesajı göstərilir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        sender: (h) async => 'cavab',
        greeting: 'Salam! Kafedə söz öyrənək 🤖',
      ),
    ));
    expect(find.text('Salam! Kafedə söz öyrənək 🤖'), findsOneWidget);
  });

  testWidgets('accent verilibsə AppBar fonu və user baloncuğu dəyişir',
      (tester) async {
    final accent = accentFor('chat');
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        sender: (h) async => 'cavab',
        accent: accent,
      ),
    ));

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, accent.tint);

    await tester.enterText(find.byType(TextField), 'salam');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    final bubble = tester.widget<Container>(
      find
          .ancestor(of: find.text('salam'), matching: find.byType(Container))
          .first,
    );
    final decoration = bubble.decoration as BoxDecoration;
    expect(decoration.color, accent.accent);
  });

  testWidgets('sender xəta atsa xəta baloncuğu göstərilir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(sender: (h) async => throw Exception('xeta')),
    ));
    await tester.enterText(find.byType(TextField), 'salam');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bağlantı yoxdur'), findsOneWidget);
  });

  group('historyLoader (2026-08-04 — çat yaddaşı)', () {
    testWidgets('tarixçə mesajları əvvəlcədən görünür, greeting yoxdur',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
          sender: (h) async => 'cavab',
          greeting: 'Bu greeting görünməməlidir',
          historyLoader: () async => const [
            ChatMessage(role: ChatRole.user, content: 'əvvəlki sualım'),
            ChatMessage(role: ChatRole.assistant, content: 'əvvəlki cavabım'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('əvvəlki sualım'), findsOneWidget);
      expect(find.text('əvvəlki cavabım'), findsOneWidget);
      expect(find.text('Bu greeting görünməməlidir'), findsNothing);
    });

    testWidgets('tarixçə boşdursa greeting göstərilir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
          sender: (h) async => 'cavab',
          greeting: 'Salam! Başlayaq 🤖',
          historyLoader: () async => const [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Salam! Başlayaq 🤖'), findsOneWidget);
    });

    testWidgets('historyLoader yoxdursa mövcud davranış dəyişmir',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
          sender: (h) async => 'cavab',
          greeting: 'Salam! Başlayaq 🤖',
        ),
      ));

      expect(find.text('Salam! Başlayaq 🤖'), findsOneWidget);
    });
  });
}
