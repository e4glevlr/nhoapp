import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VoiceChatPage extends StatefulWidget {
  const VoiceChatPage({super.key});

  @override
  State<VoiceChatPage> createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends State<VoiceChatPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _currentText = '';
  List<_Message> _messages = [];

  final String userId = "user123";
  final String sessionId = "session123";

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("vi-VN");
    _tts.setSpeechRate(0.9);
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        localeId: "vi_VN",
        onResult: (result) {
          setState(() => _currentText = result.recognizedWords);
        },
      );
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();

    if (_currentText.isNotEmpty) {
      _addMessage(_currentText, isUser: true);
      await _sendToBot(_currentText);
      _currentText = '';
    }
  }

  Future<void> _sendToBot(String inputText) async {
    final url = Uri.parse("https://aitools.ptit.edu.vn/nho/chat");

    final body = {
      "user_id": userId,
      "session_id": sessionId,
      "text": inputText,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
        jsonDecode(utf8.decode(response.bodyBytes));

        String botReply = '';
        if (jsonResponse.containsKey('response')) {
          try {
            final parsed = jsonDecode(jsonResponse['response']);
            botReply = parsed['text'] ?? jsonResponse['response'];
          } catch (_) {
            botReply = jsonResponse['response'];
          }
        }

        _addMessage(botReply, isUser: false);
        await _tts.speak(botReply);
      } else {
        _addMessage("❌ Bot lỗi: ${response.body}", isUser: false);
      }
    } catch (e) {
      _addMessage("⚠️ Gặp lỗi: $e", isUser: false);
    }
  }

  void _addMessage(String text, {required bool isUser}) {
    setState(() {
      _messages.add(_Message(text: text, isUser: isUser));
    });
  }

  Widget _buildMessage(_Message msg) {
    final alignment = msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = msg.isUser ? Colors.blue[100] : Colors.grey[300];

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: _isListening ? _stopListening : _startListening,
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isListening
                  ? [Colors.redAccent, Colors.red]
                  : [Colors.blueAccent, Colors.blue],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 4),
                blurRadius: 6,
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isListening ? Icons.stop_circle : Icons.mic,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(width: 12),
              Text(
                _isListening ? "DỪNG GHI ÂM" : "🎙️ NÓI VỚI CHATBOT",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🎙️ Voice Chat Bot")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          if (_isListening)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text("🎤 Đang nghe...", style: TextStyle(color: Colors.red)),
            ),
          _buildMicButton(),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;

  _Message({required this.text, required this.isUser});
}
