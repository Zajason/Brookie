import 'package:flutter/material.dart';
import '../shell/app_shell.dart';
import '../services/ai_chat_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';


class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_ChatMessage> _messages = [];
  int _nextId = 1;

  int? _threadId;
  bool _loadingThread = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _bootChat();
  }

  Future<void> _bootChat() async {
    try {
      // Create a fresh thread each time (simple)
      // Later you can persist last threadId in local storage and reuse it.
      final id = await AiChatService.createThread(title: "AI Assistant");
      setState(() {
        _threadId = id;
        _loadingThread = false;
      });

      // Optional: load history if you want (thread is new so empty)
      // final history = await AiChatService.fetchThreadMessages(id);
      // _applyHistory(history);

      // Add a friendly starter message
      setState(() {
        _messages.add(_ChatMessage(
          id: _nextId++,
          type: _MsgType.assistant,
          content: "Hey! Ask me anything about your spending, budgets, or cheap local options.",
          time: _nowTimeString(),
        ));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loadingThread = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chat failed to start: $e")),
      );
    }
  }

  void _applyHistory(List<Map<String, dynamic>> history) {
    // history: [{role:'user'/'assistant', content:'...', created_at:'...'}]
    final msgs = <_ChatMessage>[];
    for (final h in history) {
      final role = (h["role"] ?? "").toString();
      final content = (h["content"] ?? "").toString();
      if (content.isEmpty) continue;
      msgs.add(_ChatMessage(
        id: _nextId++,
        type: role == "user" ? _MsgType.user : _MsgType.assistant,
        content: content,
        time: _nowTimeString(), // or parse created_at if you want
      ));
    }
    setState(() => _messages.addAll(msgs));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _nowTimeString() {
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$minute $ampm";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 220,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final tid = _threadId;
    if (tid == null) return;

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(
        id: _nextId++,
        type: _MsgType.user,
        content: text,
        time: _nowTimeString(),
      ));
      _textCtrl.clear();

      // Optional: show a typing bubble immediately
      _messages.add(_ChatMessage(
        id: _nextId++,
        type: _MsgType.assistant,
        content: "…",
        time: _nowTimeString(),
        isTyping: true,
      ));
    });

    _scrollToBottom();

    try {
      final reply = await AiChatService.sendMessage(threadId: tid, message: text);

      setState(() {
        // replace the typing bubble with real text
        final typingIndex = _messages.indexWhere((m) => m.isTyping == true);
        if (typingIndex != -1) {
          _messages.removeAt(typingIndex);
        }
        _messages.add(_ChatMessage(
          id: _nextId++,
          type: _MsgType.assistant,
          content: reply,
          time: _nowTimeString(),
        ));
      });
    } catch (e) {
      setState(() {
        final typingIndex = _messages.indexWhere((m) => m.isTyping == true);
        if (typingIndex != -1) {
          _messages.removeAt(typingIndex);
        }
        _messages.add(_ChatMessage(
          id: _nextId++,
          type: _MsgType.assistant,
          content: "Sorry — something went wrong. ($e)",
          time: _nowTimeString(),
        ));
      });
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF9FAFB), Colors.white],
            ),
          ),
          child: Column(
            children: [
              // Header (unchanged)
              Container(
                padding: const EdgeInsets.fromLTRB(56, 76, 20, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Row(
                  children: [
                    _AvatarCircle(
                      size: 48,
                      child: const Text("AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      gradient: const [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "AI Assistant",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 2),
                        Text(_sending ? "Typing…" : "Online",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: _loadingThread
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _MessageRow(message: _messages[index]),
                      ),
              ),

              // Input area
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _textCtrl,
                                  onSubmitted: (_) => _send(),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Message...",
                                    hintStyle: TextStyle(color: Color(0xFF6B7280)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _SendButton(onTap: _send),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
enum _MsgType { user, assistant }

class _ChatMessage {
  final int id;
  final _MsgType type;
  final String content;
  final String time;
  final bool isTyping;

  const _ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.time,
    this.isTyping = false,
  });
}

class _AvatarCircle extends StatelessWidget {
  final double size;
  final Widget child;
  final List<Color> gradient;

  const _AvatarCircle({
    required this.size,
    required this.child,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Center(child: child),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.send, size: 18, color: Colors.white),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final _ChatMessage message;

  const _MessageRow({required this.message});

  Future<void> _openLink(String? href) async {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;

    // If launch fails, just do nothing (prevents crash)
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == _MsgType.user;

    final bubbleColor = isUser ? const Color(0xFF111827) : Colors.white;
    final textColor = isUser ? Colors.white : const Color(0xFF111827);
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
              border: isUser ? null : Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: isUser
                ? Text(
                    message.content,
                    style: TextStyle(color: textColor, height: 1.3),
                  )
                : MarkdownBody(
                    data: message.content,
                    selectable: true,
                    onTapLink: (text, href, title) => _openLink(href),
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Color(0xFF111827), height: 1.35),
                      strong: const TextStyle(fontWeight: FontWeight.w800),
                      listBullet: const TextStyle(color: Color(0xFF111827)),
                      a: const TextStyle(
                        color: Color(0xFF2563EB),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            message.time,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

