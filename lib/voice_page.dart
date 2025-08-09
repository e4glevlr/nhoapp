// voice_chat_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Full VoiceChatPage with Siri-like glowing border + glassmorphism
class VoiceChatPage extends StatefulWidget {
  const VoiceChatPage({super.key});

  @override
  State<VoiceChatPage> createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends State<VoiceChatPage>
    with TickerProviderStateMixin {
  // --- Core logic objects (unchanged) ---
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _currentText = '';
  List<_Message> _messages = [];
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  // Example IDs (replace as needed)
  final String userId = "user123";
  final String sessionId = "session123";

  // --- UI animations ---
  late final AnimationController _siriController; // for full-screen border
  late final AnimationController _bubbleController; // optional small bubbles

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("vi-VN");
    _tts.setSpeechRate(0.9);

    // animation controllers
    _siriController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _requestCameraPermission();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _cameraController?.dispose();
    _siriController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
    } else {
      // permission denied: handle if needed
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      final frontCamera = _cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      // ignore camera errors for now or show message
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.isEmpty) _cameras = await availableCameras();
    if (_cameraController == null) return;
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
      _cameraController = CameraController(newCamera, ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {});
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
        } else {
          botReply = jsonResponse['text'] ?? response.body;
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

  // --- UI building helpers (glassmorphism) ---
  Widget _glassPanel({required Widget child, double radius = 20.0}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMessage(_Message msg) {
    final alignment = msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = msg.isUser ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.06);
    final border = msg.isUser ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.08);
    final radius = msg.isUser
        ? const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(18),
    )
        : const BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
      bottomRight: Radius.circular(18),
    );

    return Align(
      alignment: alignment,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(color: border, width: 1),
            ),
            child: Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    final micBtn = SizedBox(
      width: double.infinity,
      height: 64,
      child: Center(
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
              _isListening ? "" : "",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );

    // Wrap mic button in glass + siri ring (active when listening)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SiriRing(
        active: _isListening,
        controller: _siriController,
        child: _glassPanel(child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: _isListening ? _stopListening : _startListening,
          child: micBtn,
        ), radius: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // transparent scaffold so full-screen painter shows
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // --- camera preview or gradient background ---
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(child: CameraPreview(_cameraController!))
          else
          // fallback gradient water-like background with subtle bubbles
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: const [
                    Color(0xFF071030),
                    Color(0xFF09223F),
                    Color(0xFF073B4C),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

          // --- siri glass border painter on top of content ---
          AnimatedBuilder(
            animation: _siriController,
            builder: (context, child) {
              return CustomPaint(
                painter: _SiriBorderPainter(angle: _siriController.value * 2 * math.pi),
                child: child,
              );
            },
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // AppBar area (glass)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _glassPanel(
                      radius: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              child: Icon(Icons.mic, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("🎙️ Voice Chat Bot",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 2),
                                  Text("Nói để chat — Tự động gửi kèm ảnh nếu bật camera",
                                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _toggleCamera,
                              icon: const Icon(Icons.switch_camera, color: Colors.white),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- chat area (glass panel) ---
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: _glassPanel(
                        radius: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) => _buildMessage(_messages[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- mic status (text) ---


                  // --- mic button (glass + siri ring) ---
                  _buildMicButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Siri-style ring widget: paints a moving sweep gradient ring around child
class SiriRing extends StatelessWidget {
  final Widget child;
  final bool active;
  final AnimationController controller;
  final double ringWidth;
  const SiriRing({
    super.key,
    required this.child,
    required this.controller,
    this.active = false,
    this.ringWidth = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return CustomPaint(
      painter: _RingPainter(angle: controller.value * 2 * math.pi, stroke: ringWidth),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  final double angle;
  final double stroke;
  _RingPainter({required this.angle, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(stroke / 2), Radius.circular(size.height));
    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: const [
        Color(0xFF6a11cb),
        Color(0xFF2575fc),
        Color(0xFF00c6ff),
        Color(0xFFff7ab6),
        Color(0xFF6a11cb),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      transform: GradientRotation(angle),
    );

    final paint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.stroke != stroke;
  }
}

/// Painter for full-screen Siri-like border (subtle)
class _SiriBorderPainter extends CustomPainter {
  final double angle;
  _SiriBorderPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final double thickness = math.max(3, size.shortestSide * 0.006);

    // outer glow (soft)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.02),
          Colors.transparent,
        ],
      ).createShader(rect.inflate(80))
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, glowPaint);

    // sweep gradient border
    final sweep = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: const [
        Color(0xFF6a11cb),
        Color(0xFF2575fc),
        Color(0xFF00c6ff),
        Color(0xFFff7ab6),
        Color(0xFF6a11cb),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      transform: GradientRotation(angle),
    );

    final paint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final rrect = RRect.fromRectAndRadius(rect.deflate(thickness / 2), const Radius.circular(28));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _SiriBorderPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}

class _Message {
  final String text;
  final bool isUser;
  _Message({required this.text, required this.isUser});
}
