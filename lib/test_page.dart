// lib/pages/test_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

// Giả định các file này đã được tạo và có logic như bạn cung cấp
import '../services/webrtc_service.dart';
import '../services/speech_service.dart';
import '../services/api_service.dart';
import '../models/chat_message.dart';

// Các widget giao diện đã được style lại
import '../widgets/video_view_section.dart';
import '../widgets/chat_view_section.dart';
import '../widgets/control_buttons.dart';

class TestPage extends StatefulWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with SingleTickerProviderStateMixin {
  // Thêm AnimationController cho nền động
  late AnimationController _animationController;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  // Khởi tạo các services
  late final WebRtcService _webRtcService;
  late final SpeechService _speechService;
  final ApiService _apiService = ApiService();

  // State của UI
  final TextEditingController _chatController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(text: "Chào bạn, tôi có thể giúp gì?", sender: MessageSender.bot),
  ];
  bool _isSendingToBot = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();

    _webRtcService = WebRtcService();
    _webRtcService.addListener(_updateUI);

    _speechService = SpeechService(
      onResult: _handleSpeechResult,
      onError: (errorMsg) => _addMessage(ChatMessage(text: errorMsg, sender: MessageSender.systemError)),
    );
    _speechService.addListener(_updateUI);
    _speechService.initSpeech();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
    ]).animate(_animationController);
    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
    ]).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _webRtcService.removeListener(_updateUI);
    _speechService.removeListener(_updateUI);
    _webRtcService.dispose();
    _speechService.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    _animationController.dispose();
    _initializeAnimation();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  void _handleSpeechResult(String result) {
    if (result.isNotEmpty) {
      _addMessage(ChatMessage(text: result, sender: MessageSender.userVoice));
      _sendToChatbot(result);
    }
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      _chatController.clear();
      _addMessage(ChatMessage(text: text, sender: MessageSender.user));
      _sendToChatbot(text);
    }
  }

  Future<void> _sendToChatbot(String text) async {
    setState(() => _isSendingToBot = true);
    final botReply = await _apiService.sendToChatbot(text);
    if (mounted) {
      if (botReply != null) {
        _addMessage(ChatMessage(text: botReply, sender: MessageSender.bot));
      } else {
        _addMessage(ChatMessage(text: "Lỗi kết nối tới bot.", sender: MessageSender.systemError));
      }
      setState(() => _isSendingToBot = false);
    }
  }

  void _addMessage(ChatMessage message) {
    if (mounted) {
      setState(() {
        _messages.add(message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [Color(0xFF6a11cb), Color(0xFF2575fc)],
              begin: _topAlignmentAnimation.value,
              end: _bottomAlignmentAnimation.value,
            ),
          ),
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("Trò chuyện cùng ALDA", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              VideoViewSection(
                renderer: _webRtcService.renderer,
                status: _webRtcService.status,
                isLoading: _webRtcService.isLoading,
                isListening: _speechService.isListening,
                errorMessage: _webRtcService.errorMessage,
              ),
              ControlButtons(
                isLoading: _webRtcService.isLoading,
                isConnected: _webRtcService.isConnected,
                onConnect: _webRtcService.connect,
                onDisconnect: _webRtcService.disconnect,
              ),
              ChatViewSection(
                messages: _messages,
                chatController: _chatController,
                onSendMessage: _sendMessage,
                isSendingToBot: _isSendingToBot,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: (_speechService.speechEnabled && !_isSendingToBot) ? _speechService.handleMicTap : null,
          backgroundColor: _speechService.isListening ? Colors.redAccent.withOpacity(0.9) : Colors.white.withOpacity(0.25),
          elevation: 2,
          shape: const CircleBorder(),
          child: Icon(_speechService.isListening ? Icons.mic_off_rounded : Icons.mic_rounded, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.0,
              color: Colors.white.withOpacity(0.1),
              elevation: 0,
              child: Container(height: 40.0),
            ),
          ),
        ),
      ),
    );
  }
}