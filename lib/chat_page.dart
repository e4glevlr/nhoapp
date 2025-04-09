import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MaterialApp(home: ChatPage()));
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class Message {
  final String text;
  final bool isUser;

  Message({required this.text, required this.isUser});
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();

  final String userId = "user123";
  final String sessionId = "session123";

  Future<void> sendMessage(String message) async {
    final url = Uri.parse("https://aitools.ptit.edu.vn/nho/chat");

    final body = {
      "user_id": userId,
      "session_id": sessionId,
      "text": message,
    };

    setState(() {
      _messages.add(Message(text: message, isUser: true));
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));

        String botText = '';
        if (jsonResponse.containsKey('response')) {
          final responseText = jsonResponse['response'];
          try {
            final nestedJson = jsonDecode(responseText);
            botText = nestedJson['text'] ?? responseText;
          } catch (_) {
            botText = responseText;
          }
        } else {
          botText = jsonResponse['text'] ?? response.body;
        }

        setState(() {
          _messages.add(Message(text: botText, isUser: false));
        });
      } else {
        setState(() {
          _messages.add(Message(
              text: "❌ Lỗi ${response.statusCode}: ${response.body}",
              isUser: false));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(Message(text: "⚠️ Gặp lỗi: $e", isUser: false));
      });
    }

    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildMessage(Message message) {
    return Align(
      alignment:
      message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
            message.isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight:
            message.isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text("Chat với Bot"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _buildMessage(_messages[index]),
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration.collapsed(
                      hintText: "Nhập tin nhắn...",
                    ),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        sendMessage(text.trim());
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isNotEmpty) {
                      sendMessage(text);
                    }
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
