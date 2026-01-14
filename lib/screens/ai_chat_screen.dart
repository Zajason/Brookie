import 'package:flutter/material.dart';
import '../shell/app_shell.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      id: 1,
      type: _MsgType.user,
      content: 'I am struggling to keep my eating within budget',
      time: '10:24 AM',
    ),
    _ChatMessage(
      id: 2,
      type: _MsgType.assistant,
      content:
          'You can either try and cook at home instead of eating out or eating at some more budget friendly restaurants. I could give you some recipes or recommend you a cheap but amazing restaurant in your area.',
      time: '10:24 AM',
    ),
    _ChatMessage(
      id: 3,
      type: _MsgType.user,
      content: 'Can you recommend a restaurant?',
      time: '10:25 AM',
    ),
  ];

  int _nextId = 4;

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

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          id: _nextId++,
          type: _MsgType.user,
          content: text,
          time: _nowTimeString(),
        ),
      );
      _textCtrl.clear();
    });

    // Scroll to bottom after frame paints
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });

    // TODO: later you’ll add assistant response here when LLM is wired.
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
              // Header
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
                        Text("Online", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _MessageRow(message: _messages[index]);
                  },
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

/// ---------- UI components ----------

class _MessageRow extends StatelessWidget {
  final _ChatMessage message;
  const _MessageRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == _MsgType.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _AvatarCircle(
              size: 32,
              child: const Text("AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              gradient: const [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
            ),
            const SizedBox(width: 10),
          ],

          // Bubble + time
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF3B82F6) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(24),
                      topRight: const Radius.circular(24),
                      bottomLeft: Radius.circular(isUser ? 24 : 8),
                      bottomRight: Radius.circular(isUser ? 8 : 24),
                    ),
                    boxShadow: isUser
                        ? null
                        : const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
                    border: isUser ? null : Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF1F2937),
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    message.time,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 10),
            _AvatarCircle(
              size: 32,
              child: const Text("U", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final double size;
  final Widget child;
  final List<Color> gradient;

  const _AvatarCircle({required this.size, required this.child, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0xFF3B82F6),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

/// ---------- Data ----------

enum _MsgType { user, assistant }

class _ChatMessage {
  final int id;
  final _MsgType type;
  final String content;
  final String time;

  const _ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.time,
  });
}
