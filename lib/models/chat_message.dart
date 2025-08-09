// lib/models/chat_message.dart
enum MessageSender { user, userVoice, bot, system, systemError }

class ChatMessage {
  final String text;
  final MessageSender sender;

  ChatMessage({required this.text, required this.sender});
}