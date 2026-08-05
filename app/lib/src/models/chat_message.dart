enum ChatRole {
  user('user'),
  assistant('assistant');

  const ChatRole(this.wire);
  final String wire;
}

/// Söhbətdə bir mesaj (istifadəçi və ya AI).
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final ChatRole role;
  final String content;

  Map<String, dynamic> toServerJson() => {'role': role.wire, 'content': content};

  /// `GET /chat/history`-dən gələn saxlanmış mesajı parse edir (bax spec:
  /// 2026-08-04-chat-memory-design.md). Naməlum/xarab `role` istifadəçi
  /// mesajı kimi qəbul edilir — heç vaxt sınmır.
  factory ChatMessage.fromServerJson(Map<String, dynamic> json) => ChatMessage(
        role: ChatRole.values.firstWhere(
          (r) => r.wire == json['role'],
          orElse: () => ChatRole.user,
        ),
        content: json['content'] as String,
      );
}
