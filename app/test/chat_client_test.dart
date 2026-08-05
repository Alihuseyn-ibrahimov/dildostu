import 'dart:convert';

import 'package:dildostu/src/data/chat_client.dart';
import 'package:dildostu/src/models/chat_message.dart';
import 'package:dildostu/src/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _profile = UserProfile(
  wakeHour: 8,
  sleepHour: 23,
  purpose: LearningPurpose.travel,
  level: ProficiencyLevel.beginner,
  interests: [],
);

void main() {
  test('serverin cavabını qaytarır', () async {
    final mock = MockClient((req) async =>
        http.Response.bytes(utf8.encode(jsonEncode({'reply': 'Salam!'})), 200));
    final client = ChatClient(baseUrl: 'http://x', token: 'tok', httpClient: mock);
    final reply = await client.send(
      profile: _profile,
      history: [const ChatMessage(role: ChatRole.user, content: 'salam')],
    );
    expect(reply, 'Salam!');
  });

  test('tarixçəni və profili gövdədə göndərir', () async {
    Map<String, dynamic>? body;
    final mock = MockClient((req) async {
      body = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response.bytes(utf8.encode(jsonEncode({'reply': 'ok'})), 200);
    });
    final client = ChatClient(baseUrl: 'http://x', token: 'tok', httpClient: mock);
    await client.send(
      profile: _profile,
      history: [
        const ChatMessage(role: ChatRole.user, content: 'salam'),
        const ChatMessage(role: ChatRole.assistant, content: 'salam!'),
      ],
      packId: 'cafe',
      hour: 9,
    );
    expect((body!['messages'] as List).length, 2);
    expect(body!['messages'][0]['role'], 'user');
    expect(body!['context']['pack_id'], 'cafe');
    expect(body!['profile']['level'], 'beginner');
  });

  test('yalnız son 12 mesaj göndərilir (xərc nəzarəti)', () async {
    Map<String, dynamic>? body;
    final mock = MockClient((req) async {
      body = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response.bytes(utf8.encode(jsonEncode({'reply': 'ok'})), 200);
    });
    final client = ChatClient(baseUrl: 'http://x', token: 'tok', httpClient: mock);
    final history = [
      for (var i = 0; i < 20; i++)
        ChatMessage(role: ChatRole.user, content: 'mesaj $i'),
    ];
    await client.send(profile: _profile, history: history);
    expect((body!['messages'] as List).length, 12);
    expect(body!['messages'].last['content'], 'mesaj 19');
  });

  test('server xətası istisna atır', () async {
    final mock = MockClient((req) async => http.Response('err', 502));
    final client = ChatClient(baseUrl: 'http://x', token: 'tok', httpClient: mock);
    expect(
      () => client.send(
        profile: _profile,
        history: [const ChatMessage(role: ChatRole.user, content: 'salam')],
      ),
      throwsA(isA<ChatException>()),
    );
  });

  test('send Authorization başlığı göndərir', () async {
    String? authHeader;
    final mock = MockClient((req) async {
      authHeader = req.headers['Authorization'];
      return http.Response.bytes(utf8.encode(jsonEncode({'reply': 'ok'})), 200);
    });
    final client = ChatClient(baseUrl: 'http://x', token: 'sirr-token', httpClient: mock);
    await client.send(
      profile: _profile,
      history: [const ChatMessage(role: ChatRole.user, content: 'salam')],
    );
    expect(authHeader, 'Bearer sirr-token');
  });

  group('fetchHistory', () {
    test('Authorization başlığı ilə düzgün endpoint-ə gedir', () async {
      String? path;
      String? authHeader;
      final mock = MockClient((req) async {
        path = req.url.path;
        authHeader = req.headers['Authorization'];
        return http.Response.bytes(
            utf8.encode(jsonEncode({'messages': []})), 200);
      });
      final client = ChatClient(baseUrl: 'http://x', token: 'tok', httpClient: mock);
      await client.fetchHistory();
      expect(path, '/chat/history');
      expect(authHeader, 'Bearer tok');
    });

    test('mesajları parse edir', () async {
      final mock = MockClient((req) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'messages': [
                {'role': 'user', 'content': 'salam', 'created_at': 'x'},
                {'role': 'assistant', 'content': 'salam!', 'created_at': 'y'},
              ],
            })),
            200,
          ));
      final client = ChatClient(baseUrl: 'http://x', token: 'tok', httpClient: mock);
      final messages = await client.fetchHistory();
      expect(messages, hasLength(2));
      expect(messages[0].role, ChatRole.user);
      expect(messages[0].content, 'salam');
      expect(messages[1].role, ChatRole.assistant);
    });

    test('server xətasında boş siyahı qaytarır (istisna atmır)', () async {
      final mock = MockClient((req) async => http.Response('err', 401));
      final client = ChatClient(baseUrl: 'http://x', token: 'tok', httpClient: mock);
      expect(await client.fetchHistory(), isEmpty);
    });
  });
}
