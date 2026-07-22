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
    final client = ChatClient(baseUrl: 'http://x', httpClient: mock);
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
    final client = ChatClient(baseUrl: 'http://x', httpClient: mock);
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
    final client = ChatClient(baseUrl: 'http://x', httpClient: mock);
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
    final client = ChatClient(baseUrl: 'http://x', httpClient: mock);
    expect(
      () => client.send(
        profile: _profile,
        history: [const ChatMessage(role: ChatRole.user, content: 'salam')],
      ),
      throwsA(isA<ChatException>()),
    );
  });
}
