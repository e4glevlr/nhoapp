// lib/voice_chat_page.dart

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

class VoiceChatPage extends StatefulWidget {
  const VoiceChatPage({super.key});

  @override
  State<VoiceChatPage> createState() => _VoiceChatPageState();
}

class _VoiceChatPageState extends State<VoiceChatPage>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _currentText = '';
  final List<_Message> _messages = [];
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  final String userId = "user123";
  final String sessionId = "session123";

  late final AnimationController _siriController;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("vi-VN");
    _tts.setSpeechRate(0.9);

    _siriController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _requestCameraPermission();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _cameraController?.dispose();
    _siriController.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
    }
  }

  Future<void> _initializeCamera({bool useFrontCamera = true}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final selectedCamera = _cameras.firstWhere(
            (camera) => useFrontCamera
            ? camera.lensDirection == CameraLensDirection.front
            : camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      // Dispose the old controller before creating a new one
      await _cameraController?.dispose();

      _cameraController = CameraController(selectedCamera, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameraController == null) return;
    final currentLens = _cameraController!.description.lensDirection;
    await _initializeCamera(useFrontCamera: currentLens == CameraLensDirection.back);
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

  Widget _glassPanel({required Widget child, double radius = 20.0, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMessage(_Message msg) {
    final alignment = msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = msg.isUser ? Colors.blue.withOpacity(0.3) : Colors.white.withOpacity(0.1);
    final radius = msg.isUser
        ? const BorderRadius.only(
        topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18))
        : const BorderRadius.only(
        topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18));

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3)),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: _glassPanel(
              radius: 32,
              child: IconButton(
                onPressed: _toggleCamera,
                icon: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white70),
                tooltip: 'Xoay camera',
              ),
            ),
          ),
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: SiriRing(
              active: _isListening,
              controller: _siriController,
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF2575fc), Color(0xFF6a11cb)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(_isListening ? Icons.stop : Icons.mic_none, color: Colors.white, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 64, height: 64),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // LỚP 1: NỀN (CAMERA HOẶC GRADIENT)
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF071030), Color(0xFF09223F), Color(0xFF073B4C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

          // LỚP 2: GIAO DIỆN CHAT VÀ ĐIỀU KHIỂN
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
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 70, bottom: 16),
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final reversedIndex = _messages.length - 1 - index;
                        return _buildMessage(_messages[reversedIndex]);
                      },
                    ),
                  ),
                  _buildControls(),
                ],
              ),
            ),
          ),

          // LỚP 3: NÚT QUAY LẠI (LUÔN Ở TRÊN CÙNG) - kính mờ tròn 44 tương tự trang khác
          Positioned(
            top: MediaQuery.of(context).padding.top + ((kToolbarHeight - 44) / 2) + 8,
            left: 16,
            child: SizedBox(
              width: 44,
              height: 44,
              child: _glassPanel(
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Quay lại',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _SiriBorderPainter extends CustomPainter {
  final double angle;
  _SiriBorderPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final double thickness = math.max(3, size.shortestSide * 0.006);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.02),
          Colors.transparent,
        ],
      ).createShader(rect.inflate(80))
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, glowPaint);

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