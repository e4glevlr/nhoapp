// lib/pages/test_page.dart
import 'package:flutter/material.dart';

// Giả định các file này đã được tạo và có logic như bạn cung cấp
import '../services/webrtc_service.dart';
import '../services/speech_service.dart';
import '../services/api_service.dart';
import '../models/chat_message.dart';

// Các widget giao diện đã được style lại
import '../widgets/video_view_section.dart';
import '../widgets/chat_view_section.dart';
import '../widgets/control_buttons.dart';
import 'components/GlassmorphicToggle.dart';

class TestPage extends StatefulWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {

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

    _webRtcService = WebRtcService();
    _webRtcService.addListener(_updateUI);

    _speechService = SpeechService(
      onResult: _handleSpeechResult,
      onError: (errorMsg) => _addMessage(ChatMessage(text: errorMsg, sender: MessageSender.systemError)),
    );
    _speechService.addListener(_updateUI);
    _speechService.initSpeech();
  }

  

  @override
  void dispose() {
    _webRtcService.removeListener(_updateUI);
    _speechService.removeListener(_updateUI);
    _webRtcService.dispose();
    _speechService.dispose();
    _chatController.dispose();
    super.dispose();
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6a11cb), Color(0xFF2575fc)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: null,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // Header ẩn (chỉ có nút quay lại ở góc trên trái như schedule_page)
                SizedBox(
                  height: kToolbarHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 0),
                          child: GlassmorphicContainer(
                            borderOpacity: 0.12,
                            borderWidth: 1,
                            borderRadius: 50,
                            blurSigma: 14,
                            isPerformanceMode: false,
                            child: SizedBox.square(
                              dimension: 44,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                  size: 20,
                                ),
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
                // Khu vực video
                VideoViewSection(
                  renderer: _webRtcService.renderer,
                  status: _webRtcService.status,
                  isLoading: _webRtcService.isLoading,
                  isListening: _speechService.isListening,
                  errorMessage: _webRtcService.errorMessage,
                ),
                const SizedBox(height: 8),
                // Nút điều khiển trong khung kính mờ
                GlassmorphicContainer(
                  borderRadius: 20,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ControlButtons(
                      isLoading: _webRtcService.isLoading,
                      isConnected: _webRtcService.isConnected,
                      onConnect: _webRtcService.connect,
                      onDisconnect: _webRtcService.disconnect,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Khu vực chat (đã có kính mờ bên trong)
                ChatViewSection(
                  messages: _messages,
                  chatController: _chatController,
                  onSendMessage: _sendMessage,
                  isSendingToBot: _isSendingToBot,
                  isMicEnabled: _speechService.speechEnabled && !_isSendingToBot,
                  isListening: _speechService.isListening,
                  onMicTap: _speechService.handleMicTap,
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar: null,
      ),
    );
  }
}