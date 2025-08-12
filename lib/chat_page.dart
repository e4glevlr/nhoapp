import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/animation.dart';
import 'components/GlassmorphicToggle.dart' as gm;

void main() {
  runApp(const MaterialApp(
    home: ChatPage(),
    debugShowCheckedModeBanner: false,
  ));
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

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();

  late AnimationController _animationController;
  // THAY ĐỔI: Xóa các animation không cần thiết cho gradient
  // late Animation<Alignment> _topAlignmentAnimation;
  // late Animation<Alignment> _bottomAlignmentAnimation;

  final String userId = "user123";
  final String sessionId = "session123";

  @override
  void initState() {
    super.initState();
    // THAY ĐỔI: Đơn giản hóa AnimationController để điều khiển opacity
    _animationController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 10)
    )..repeat(reverse: true); // Lặp lại và đảo ngược (mờ dần -> hiện rõ)
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage(String message) async {
    final url = Uri.parse("https://aitools.ptit.edu.vn/nho/chat");
    final body = {"user_id": userId, "session_id": sessionId, "text": message};

    setState(() {
      _messages.add(Message(text: message, isUser: true));
    });
    _scrollToBottom();

    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'}, body: body);
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
          _messages.add(Message(text: "❌ Lỗi ${response.statusCode}: ${response.body}", isUser: false));
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
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildGlassMessageBubble(Message message) {
    final bubbleAlignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    return Align(
      alignment: bubbleAlignment,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: gm.GlassmorphicContainer(
            isPerformanceMode: true,
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                message.text,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15, height: 1.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: gm.GlassmorphicContainer(
        isPerformanceMode: true,
        borderRadius: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Nhập tin nhắn...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) sendMessage(text.trim());
                  },
                ),
              ),
              GestureDetector(
                onTap: () {
                  final text = _controller.text.trim();
                  if (text.isNotEmpty) sendMessage(text);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(2, 2))],
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // THAY ĐỔI: Sử dụng Stack để xếp chồng 2 lớp gradient và giao diện
    return Stack(
      children: [
        // Lớp nền 1 (cố định)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6a11cb), Color(0xFF2575fc)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Lớp nền 2 (chuyển động mờ dần)
        FadeTransition(
          opacity: _animationController,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFff7ab6), Color(0xFF6ea8fe)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
        ),

        // Lớp giao diện Scaffold nằm trên cùng
        Scaffold(
          backgroundColor: Colors.transparent, // Rất quan trọng!

          body: Padding(
            padding: const EdgeInsets.only(top: 32.0),
            child: Column(
              children: [
              // Header ẩn + nút back kính mờ
              SizedBox(
                height: kToolbarHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, top: 8),
                        child: gm.GlassmorphicContainer(
                          borderOpacity: 0.12,
                          borderWidth: 1,
                          borderRadius: 50,
                          blurSigma: 14,
                          isPerformanceMode: false,
                          child: SizedBox.square(
                            dimension: 44,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Quay lại',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _buildGlassMessageBubble(_messages[index]),
                ),
              ),
              _buildTextInputArea(),
            ],
          ),
        ),
        ),
      ],
    );
  }
}