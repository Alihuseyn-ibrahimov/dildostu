import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import 'accent_colors.dart';

/// AI ilə iki-tərəfli söhbət ekranı. `sender` cari tarixçəni serverə göndərib
/// AI cavabını qaytarır (main.dart-da ChatClient-ə bağlanır; testdə fake).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.sender,
    this.greeting,
    this.accent,
  });

  /// Bütün tarixçəni alıb AI cavabını (və ya xəta atır) qaytarır.
  final Future<String> Function(List<ChatMessage> history) sender;

  /// İlk açılışda göstərilən AI salamı (məs. kartdan gələndə kontekstli).
  final String? greeting;

  /// Xüsusiyyətin sabit aksent rəngi (bax `accent_colors.dart`). Null olsa
  /// mövcud neytral tema rəngləri işlədilir.
  final AccentColor? accent;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.greeting != null) {
      _messages.add(ChatMessage(role: ChatRole.assistant, content: widget.greeting!));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final reply = await widget.sender(List.unmodifiable(_messages));
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(role: ChatRole.assistant, content: reply)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.add(const ChatMessage(
          role: ChatRole.assistant,
          content: '⚠️ Bağlantı yoxdur, yenidən cəhd edin.')));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI ilə söhbət'),
        backgroundColor: widget.accent?.tint,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) return const _TypingBubble();
                return _Bubble(message: _messages[i], accent: widget.accent);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Sualını yaz...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.accent});
  final ChatMessage message;
  final AccentColor? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == ChatRole.user;
    final userColor = accent?.accent ?? theme.colorScheme.primary;
    final onUserColor = accent?.onAccent ?? theme.colorScheme.onPrimary;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? userColor : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isUser ? onUserColor : null),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text('AI yazır…'),
      ),
    );
  }
}
