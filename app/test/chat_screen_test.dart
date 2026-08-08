import 'package:dildostu/src/data/chat_client.dart';
import 'package:dildostu/src/models/chat_message.dart';
import 'package:dildostu/src/models/chat_quota.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'locale_test_harness.dart';

void main() {
  testWidgets('AppBar LachinGo başlığını göstərir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(sender: (h) async => 'cavab'),
    ));
    expect(find.text('LachinGo ilə söhbət'), findsOneWidget);
  });

  testWidgets('quickPrompts boş söhbətdə görünür və göndərir', (tester) async {
    List<ChatMessage>? received;
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        sender: (history) async {
          received = history;
          return 'cavab';
        },
        greeting: 'Salam!',
        quickPrompts: const ['Aeroportda nə deyim?'],
      ),
    ));

    expect(find.text('Tez suallar'), findsOneWidget);
    expect(find.text('Aeroportda nə deyim?'), findsOneWidget);

    await tester.tap(find.text('Aeroportda nə deyim?'));
    await tester.pumpAndSettle();

    expect(received!.last.content, 'Aeroportda nə deyim?');
    expect(find.text('cavab'), findsOneWidget);
  });

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

  testWidgets('naməlum xətada ümumi mesaj göstərilir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(sender: (h) async => throw Exception('xeta')),
    ));
    await tester.enterText(find.byType(TextField), 'salam');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gözlənilməz xəta'), findsOneWidget);
  });

  group('xəta idarəsi (2026-08-06)', () {
    Future<void> sendOnce(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
    }

    testWidgets('keçici xətada "Yenidən cəhd et" görünür və mətni təkrar '
        'göndərir', (tester) async {
      final sent = <String>[];
      var shouldFail = true;
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(sender: (history) async {
          sent.add(history.last.content);
          if (shouldFail) {
            throw const ChatException('AI cavab vermir',
                kind: ChatErrorKind.aiUnavailable);
          }
          return 'nəhayət cavab';
        }),
      ));

      await sendOnce(tester, 'salam');
      expect(find.text('Yenidən cəhd et'), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.text('Yenidən cəhd et'));
      await tester.pumpAndSettle();

      // Eyni mətn təkrar göndərildi, istifadəçi yenidən yazmadı.
      expect(sent, ['salam', 'salam']);
      expect(find.text('nəhayət cavab'), findsOneWidget);
      expect(find.text('Yenidən cəhd et'), findsNothing);
      // Mesaj təkrarlanmır — yalnız bir dəfə baloncuq var.
      expect(find.text('salam'), findsOneWidget);
    });

    testWidgets('limit xətasında təkrar düyməsi göstərilmir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
          sender: (h) async => throw const ChatException(
              'Bu gün üçün söhbət limitin doldu (80 mesaj).',
              kind: ChatErrorKind.quota),
        ),
      ));
      await sendOnce(tester, 'salam');

      expect(find.textContaining('limitin doldu'), findsOneWidget);
      expect(find.text('Yenidən cəhd et'), findsNothing);
      expect(find.byIcon(Icons.hourglass_bottom), findsOneWidget);
    });

    testWidgets('uğurlu mesajdan sonra xəta zolağı itir', (tester) async {
      var shouldFail = true;
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(sender: (h) async {
          if (shouldFail) {
            throw const ChatException('yoxdur', kind: ChatErrorKind.network);
          }
          return 'cavab';
        }),
      ));

      await sendOnce(tester, 'birinci');
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      shouldFail = false;
      await sendOnce(tester, 'ikinci');
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });
  });

  testWidgets('AI cavabındakı markdown ulduzları göstərilmir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(sender: (h) async => 'Bunu **yadda saxla**.'),
    ));
    await tester.enterText(find.byType(TextField), 'salam');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('yadda saxla'), findsOneWidget);
  });

  testWidgets('AI mesajını uzun basanda kopyala seçimi çıxır', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(sender: (h) async => 'kopyalanacaq cavab'),
    ));
    await tester.enterText(find.byType(TextField), 'salam');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('kopyalanacaq cavab'));
    await tester.pumpAndSettle();

    expect(find.text('Kopyala'), findsOneWidget);
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

    testWidgets('yeni mesaj göndərildikdən sonra ekranda qalır (lokal state)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
          sender: (h) async => 'yeni cavab',
          historyLoader: () async => const [
            ChatMessage(role: ChatRole.user, content: 'köhnə sual'),
            ChatMessage(role: ChatRole.assistant, content: 'köhnə cavab'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'yeni sual');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('köhnə sual'), findsOneWidget);
      expect(find.text('köhnə cavab'), findsOneWidget);
      expect(find.text('yeni sual'), findsOneWidget);
      expect(find.text('yeni cavab'), findsOneWidget);
    });
  });

  testWidgets('kvota zolağı quotaLoader ilə göstərilir', (tester) async {
    await tester.pumpWidget(wrapWithLocale(ChatScreen(
      sender: (h) async => 'cavab',
      quotaLoader: () async =>
          const ChatQuota(used: 12, limit: 80, remaining: 68),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('12/80'), findsOneWidget);
    expect(find.textContaining('Qalıb 68'), findsOneWidget);
  });

  testWidgets('mesaj göndərildikdən sonra kvota yenilənir', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrapWithLocale(ChatScreen(
      sender: (h) async => 'cavab',
      quotaLoader: () async {
        calls++;
        return ChatQuota(used: calls, limit: 80, remaining: 80 - calls);
      },
    )));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('1/80'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'salam');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.textContaining('2/80'), findsOneWidget);
  });
}
