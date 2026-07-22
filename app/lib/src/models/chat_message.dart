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
}
