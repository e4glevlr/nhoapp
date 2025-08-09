import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:logger/logger.dart';

class SpeechService extends ChangeNotifier {
  final Logger _logger = Logger();
  final SpeechToText _speechToText = SpeechToText();

  bool _speechEnabled = false;
  bool get speechEnabled => _speechEnabled;

  bool _isListening = false;
  bool get isListening => _isListening;

  String _lastWords = '';
  String get lastWords => _lastWords;

  // Callback để trả kết quả cuối cùng về UI
  final Function(String) onResult;
  final Function(String) onError;

  SpeechService({required this.onResult, required this.onError});

  Future<void> initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) => _onSpeechError(error.errorMsg),
      );
      _logger.i("Speech recognition initialized: $_speechEnabled");
    } catch (e) {
      _logger.e("Error initializing speech: $e");
      _speechEnabled = false;
      onError("Error initializing speech recognition.");
    }
    notifyListeners();
  }

  void _onSpeechStatus(String status) {
    _isListening = status == 'listening';
    _logger.i("Speech status: $status");
    notifyListeners();
  }

  void _onSpeechError(String errorMsg) {
    _logger.e("Speech error: $errorMsg");
    _isListening = false;
    onError("Speech recognition error: $errorMsg");
    notifyListeners();
  }

  void _onSpeechResult(result) {
    _lastWords = result.recognizedWords;
    if (result.finalResult) {
      _logger.i("Final speech result: $_lastWords");
      onResult(_lastWords); // Gửi kết quả cuối cùng
      _lastWords = '';
    }
    notifyListeners();
  }

  void startListening() {
    if (!_speechEnabled || _isListening) return;
    _lastWords = '';
    _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'en_US',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
    );
    notifyListeners();
  }

  void stopListening() {
    if (!_speechToText.isListening) return;
    _speechToText.stop();
    notifyListeners();
  }

  void handleMicTap() {
    if (!_speechEnabled) return;
    _isListening ? stopListening() : startListening();
  }

  @override
  void dispose() {
    _speechToText.cancel();
    super.dispose();
  }
}