/// Proaktiv chat bildirişi modeli.
class ChatNudge {
  const ChatNudge({required this.body, required this.quickPrompt});

  final String body;
  final String quickPrompt;

  factory ChatNudge.fromJson(Map<String, dynamic> json) => ChatNudge(
        body: json['body'] as String,
        quickPrompt: json['quick_prompt'] as String,
      );
}
