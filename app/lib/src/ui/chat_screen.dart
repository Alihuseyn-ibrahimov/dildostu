import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_client.dart';
import '../models/chat_message.dart';
import '../models/chat_quota.dart';
import '../services/speaker.dart';
import 'accent_colors.dart';
import 'chat_markdown.dart';
import 'chat_quota_bar.dart';
import 'theme.dart';

/// AI ilə iki-tərəfli söhbət ekranı. `sender` cari tarixçəni serverə göndərib
/// AI cavabını qaytarır (main.dart-da ChatClient-ə bağlanır; testdə fake).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.sender,
    this.greeting,
    this.accent,
    this.historyLoader,
    this.quotaLoader,
    this.quickPrompts = const [],
    this.speaker,
  });

  /// Bütün tarixçəni alıb AI cavabını (və ya xəta atır) qaytarır.
  final Future<String> Function(List<ChatMessage> history) sender;

  /// İlk açılışda göstərilən AI salamı (məs. kartdan gələndə kontekstli).
  /// Saxlanmış tarixçə boş deyilsə göstərilmir (təkrar salamlama qarışıqlıq
  /// yaradar) — bax `historyLoader`.
  final String? greeting;

  /// Saxlanmış çat tarixçəsini gətirir (bax spec:
  /// 2026-08-04-chat-memory-design.md). Null olsa mövcud davranış (yalnız
  /// `greeting`, tarixçə yoxdur) dəyişmir.
  final Future<List<ChatMessage>> Function()? historyLoader;

  /// Gündəlik mesaj kvotası (GET /chat/quota). Null olsa zolaq göstərilmir.
  final Future<ChatQuota?> Function()? quotaLoader;

  /// Xüsusiyyətin sabit aksent rəngi (bax `accent_colors.dart`). Null olsa
  /// mövcud neytral tema rəngləri işlədilir.
  final AccentColor? accent;

  /// Boş söhbətdə sürətli sual düymələri.
  final List<String> quickPrompts;

  /// Verilsə, AI cavabını səsləndirmək mümkün olur.
  final Speaker? speaker;

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _historyLoaded = false;

  /// Uğursuz sorğunun mətni — "Yenidən cəhd et" bunu təkrar göndərir.
  String? _failedText;
  ChatException? _error;
  ChatQuota? _quota;

  @override
  void initState() {
    super.initState();
    final loader = widget.historyLoader;
    if (loader != null) {
      loader().then((history) {
        if (!mounted) return;
        setState(() {
          _historyLoaded = true;
          if (history.isNotEmpty) {
            _messages.addAll(history);
          } else if (widget.greeting != null) {
            _messages.add(
                ChatMessage(role: ChatRole.assistant, content: widget.greeting!));
          }
        });
        _scrollToEnd();
      });
    } else {
      _historyLoaded = true;
      if (widget.greeting != null) {
        _messages.add(ChatMessage(role: ChatRole.assistant, content: widget.greeting!));
      }
    }
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    final loader = widget.quotaLoader;
    if (loader == null) return;
    final quota = await loader();
    if (mounted) setState(() => _quota = quota);
  }

  bool get _showQuickPrompts =>
      _historyLoaded &&
      !_sending &&
      _error == null &&
      widget.quickPrompts.isNotEmpty &&
      _messages.length <= 1 &&
      (_messages.isEmpty || _messages.every((m) => m.role == ChatRole.assistant));

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    widget.speaker?.stop();
    super.dispose();
  }

  /// Bildirişdən gələn hazır sualı input-a yazır (istifadəçi göndərir).
  void applyDraftPrompt(String text) {
    if (!mounted || text.trim().isEmpty) return;
    setState(() => _controller.text = text.trim());
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _sending = true;
      _error = null;
      _failedText = null;
    });
    _scrollToEnd();
    await _dispatch(text);
  }

  /// Uğursuz mesajı yenidən göndərir — istifadəçi mətni təkrar yazmır.
  Future<void> _retry() async {
    final text = _failedText;
    if (text == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    await _dispatch(text);
  }

  Future<void> _dispatch(String text) async {
    try {
      final reply = await widget.sender(List.unmodifiable(_messages));
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: ChatRole.assistant, content: reply));
        _failedText = null;
      });
      await _loadQuota();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ChatException
            ? e
            : const ChatException('Gözlənilməz xəta baş verdi.',
                kind: ChatErrorKind.unknown);
        _failedText = text;
      });
      if (e is ChatException && e.kind == ChatErrorKind.quota) {
        await _loadQuota();
      }
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

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kopyalandı'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('LachinGo ilə söhbət'),
        backgroundColor: accent?.tint,
      ),
      body: Column(
        children: [
          if (widget.quotaLoader != null) ChatQuotaBar(quota: _quota),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return _TypingBubble(accent: accent);
                }
                final message = _messages[i];
                return _Bubble(
                  message: message,
                  accent: accent,
                  onCopy: () => _copy(message.content),
                  onSpeak: widget.speaker == null ||
                          message.role == ChatRole.user
                      ? null
                      : () => widget.speaker!.speak(message.content),
                );
              },
            ),
          ),
          if (_error != null)
            _ErrorBanner(
              error: _error!,
              onRetry: _error!.isRetryable && _failedText != null ? _retry : null,
              onDismiss: () => setState(() => _error = null),
            ),
          if (_showQuickPrompts)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tez suallar',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.quickPrompts
                        .map((q) => ActionChip(
                              label: Text(q),
                              onPressed: () => _send(q),
                            ))
                        .toList(),
                  ),
                ],
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
                      decoration: InputDecoration(
                        hintText: _showQuickPrompts
                            ? 'Sualını yaz və ya yuxarıdan seç...'
                            : 'Sualını yaz...',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(),
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

/// Xəta zolağı — növünə uyğun mesaj; keçici xətada "Yenidən cəhd et".
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.error,
    required this.onDismiss,
    this.onRetry,
  });

  final ChatException error;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;

  IconData get _icon => switch (error.kind) {
        ChatErrorKind.network => Icons.wifi_off,
        ChatErrorKind.quota => Icons.hourglass_bottom,
        ChatErrorKind.aiUnavailable => Icons.cloud_off,
        ChatErrorKind.unauthorized => Icons.lock_outline,
        ChatErrorKind.unknown => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isQuota = error.kind == ChatErrorKind.quota;
    final bg = isQuota
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.errorContainer;
    final fg = isQuota
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onErrorContainer;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(error.message,
                style: theme.textTheme.bodySmall?.copyWith(color: fg)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Yenidən cəhd et'),
            )
          else
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: fg),
              tooltip: 'Bağla',
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    this.accent,
    this.onCopy,
    this.onSpeak,
  });

  final ChatMessage message;
  final AccentColor? accent;
  final VoidCallback? onCopy;
  final VoidCallback? onSpeak;

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onSpeak != null)
              ListTile(
                leading: const Icon(Icons.volume_up),
                title: const Text('Səsləndir'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onSpeak!();
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Kopyala'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onCopy?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == ChatRole.user;
    final userColor = accent?.accent ?? theme.colorScheme.primary;
    final onUserColor = accent?.onAccent ?? theme.colorScheme.onPrimary;
    final aiColor = accent?.tint ?? theme.colorScheme.surfaceContainerHighest;
    final aiTextColor = accent?.accent ?? theme.colorScheme.onSurface;
    final textStyle = TextStyle(
      color: isUser ? onUserColor : aiTextColor,
      height: 1.35,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: accent?.tint ?? theme.colorScheme.primaryContainer,
              child: const Text('🐦', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showActions(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? userColor : aiColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppSpacing.radiusControl),
                    topRight: const Radius.circular(AppSpacing.radiusControl),
                    bottomLeft: Radius.circular(isUser ? AppSpacing.radiusControl : 4),
                    bottomRight: Radius.circular(isUser ? 4 : AppSpacing.radiusControl),
                  ),
                ),
                child: isUser
                    ? Text(message.content, style: textStyle)
                    : ChatMarkdown(text: message.content, style: textStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({this.accent});
  final AccentColor? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: accent?.tint ?? theme.colorScheme.primaryContainer,
            child: const Text('🐦', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent?.tint ?? theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
            ),
            child: Text(
              'LachinGo yazır…',
              style: TextStyle(
                color: accent?.accent ?? theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
