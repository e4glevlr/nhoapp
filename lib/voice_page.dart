import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:http_parser/http_parser.dart'; // added import for http_parser

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
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraVisible = false;

  final String userId = "user123";
  final String sessionId = "session123";

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("vi-VN");
    _tts.setSpeechRate(1.0);
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    final frontCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );
    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController!.initialize();
    setState(() {});
  }

  Future<void> _toggleCameraVisibility() async {
    if (_cameraController == null) {
      await _initializeCamera();
    }
    setState(() {
      _isCameraVisible = !_isCameraVisible;
    });
  }

  Future<void> _toggleCamera() async {
    // Ensure cameras are available
    if (_cameras.isEmpty) _cameras = await availableCameras();
    if (_cameraController != null) {
      final currentLens = _cameraController!.description.lensDirection;
      CameraDescription newCamera;
      if (currentLens == CameraLensDirection.front) {
        newCamera = _cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
          orElse: () => _cameraController!.description,
        );
      } else {
        newCamera = _cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => _cameraController!.description,
        );
      }
      if (newCamera != _cameraController!.description) {
        await _cameraController!.dispose();
        _cameraController = CameraController(
          newCamera,
          ResolutionPreset.medium,
        );
        await _cameraController!.initialize();
        setState(() {});
      }
    }
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
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final image = await _cameraController!.takePicture();
        await _sendToBot(_currentText, imageFile: image);
      } else {
        await _sendToBot(_currentText);
      }
      _currentText = '';
    }
  }

  Future<void> _sendToBot(String inputText, {XFile? imageFile}) async {
    final uri = Uri.parse("https://aitools.ptit.edu.vn/nho/analyze-image");
    var request = http.MultipartRequest('POST', uri);
    request.fields['user_id'] = userId;
    request.fields['session_id'] = sessionId;
    request.fields['text'] = inputText;
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
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
        child: Text(msg.text, style: const TextStyle(fontSize: 16)),
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
              colors:
                  _isListening
                      ? [Colors.redAccent, Colors.red]
                      : [Colors.blueAccent, Colors.blue],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 4),
                blurRadius: 6,
              ),
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
                _isListening ? "DỪNG GHI ÂM" : "NÓI VỚI CHATBOT",
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
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🎙️ Voice Chat Bot")),
      body: Stack(
        children: [
          if (_cameraController != null &&
              _cameraController!.value.isInitialized &&
              _isCameraVisible)
            SizedBox.expand(child: CameraPreview(_cameraController!)),
          Column(
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
                  child: Text(
                    "🎤 Đang nghe...",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              _buildMicButton(),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: _toggleCameraVisibility,
                  mini: true,
                  child: Icon(_isCameraVisible ? Icons.camera_alt : Icons.camera),
                ),
                if (_isCameraVisible) ...[
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    onPressed: _toggleCamera,
                    mini: true,
                    child: const Icon(Icons.switch_camera),
                  ),
                ],
              ],
            ),
          ),
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