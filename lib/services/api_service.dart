// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class ApiService {
  final Logger _logger = Logger();
  final String _userId = 'flutter_user_test_001';
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  final String _chatApiUrl = 'https://aitools.ptit.edu.vn/nho/chat';
  final String _aldaApiUrl = 'https://aitools.ptit.edu.vn/alda_backend/human';

  Future<String?> sendToChatbot(String inputText) async {
    _logger.i("Sending to chatbot API: $_chatApiUrl");
    try {
      final uri = Uri.parse(_chatApiUrl);
      var request = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = _userId
        ..fields['session_id'] = _sessionId
        ..fields['text'] = inputText;

      final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final String? botReply = jsonResponse['response'] as String?;
        if (botReply != null && botReply.isNotEmpty) {
          await _sendResponseToAldaBackend(botReply);
          return botReply;
        }
        _logger.w("Chatbot response field is missing or empty.");
        return "(Received an empty or invalid response)";
      } else {
        _logger.e("Chatbot API Error: ${response.statusCode}\nBody: ${response.body}");
        return "(Error ${response.statusCode} calling bot)";
      }
    } catch (e) {
      _logger.e("Error sending to chatbot API", error: e);
      return "(Error connecting to bot)";
    }
  }

  Future<void> _sendResponseToAldaBackend(String botReplyText) async {
    _logger.i("Sending bot response to Alda Backend: $_aldaApiUrl");
    try {
      final requestBody = {'text': botReplyText, 'type': 'echo'};
      final response = await http
          .post(
        Uri.parse(_aldaApiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.i("Successfully sent response to Alda Backend. Status: ${response.statusCode}");
      } else {
        _logger.e("Failed to send to Alda Backend. Status: ${response.statusCode}");
      }
    } catch (e) {
      _logger.e("Error sending response to Alda Backend", error: e);
    }
  }
}