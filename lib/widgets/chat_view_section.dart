// lib/widgets/chat_view_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_message.dart';
import 'package:gioapp/components/GlassmorphicToggle.dart';

class ChatViewSection extends StatelessWidget {
  final List<ChatMessage> messages;
  final TextEditingController chatController;
  final VoidCallback onSendMessage;
  final bool isSendingToBot;
  final bool isMicEnabled;
  final bool isListening;
  final VoidCallback onMicTap;

  const ChatViewSection({
    Key? key,
    required this.messages,
    required this.chatController,
    required this.onSendMessage,
    required this.isSendingToBot,
    required this.isMicEnabled,
    required this.isListening,
    required this.onMicTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    // Tự động cuộn xuống khi có tin nhắn mới
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Expanded(
      flex: 2,
      child: GlassmorphicContainer(
        // margin: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(10.0),
                itemCount: messages.length,
                itemBuilder: (context, index) => _ChatMessageBubble(message: messages[index]),
              ),
            ),
            if (isSendingToBot)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                  const SizedBox(width: 8),
                  Text("Bot đang trả lời...", style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70)),
                ]),
              ),
            Divider(height: 1, color: Colors.white.withOpacity(0.2)),
            _ChatInputArea(
              chatController: chatController,
              onSendMessage: onSendMessage,
              isMicEnabled: isMicEnabled,
              isListening: isListening,
              onMicTap: onMicTap,
            ),
          ],
        ),
      ),
    );
  }
}

// Widget cho bong bóng chat
class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatMessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.sender == MessageSender.user || message.sender == MessageSender.userVoice;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.15);
    final borderRadius = isUser
        ? const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15), bottomLeft: Radius.circular(15))
        : const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15), bottomRight: Radius.circular(15));

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(color: color, borderRadius: borderRadius),
        child: Text(message.text, style: GoogleFonts.inter(color: Colors.white)),
      ),
    );
  }
}

// Widget cho khu vực nhập liệu
class _ChatInputArea extends StatelessWidget {
  final TextEditingController chatController;
  final VoidCallback onSendMessage;
  final bool isMicEnabled;
  final bool isListening;
  final VoidCallback onMicTap;

  const _ChatInputArea({Key? key, required this.chatController, required this.onSendMessage, required this.isMicEnabled, required this.isListening, required this.onMicTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: chatController,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: "Nhập tin nhắn...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onSubmitted: (_) => onSendMessage(),
            ),
          ),
          IconButton(
            icon: Icon(
              isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: isMicEnabled ? Colors.white : Colors.white54,
            ),
            onPressed: isMicEnabled ? onMicTap : null,
            tooltip: isListening ? 'Tắt mic' : 'Bật mic',
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            onPressed: onSendMessage,
          ),
        ],
      ),
    );
  }
}