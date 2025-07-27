import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ===================================================================
// 1. DATA MODELS (ĐÃ CẬP NHẬT)
// ===================================================================

class QuizResponse {
  final String quizId;
  final List<Question> questions;

  QuizResponse({required this.quizId, required this.questions});

  factory QuizResponse.fromJson(Map<String, dynamic> json) {
    var questionList = json['questions'] as List;
    List<Question> questions =
    questionList.map((i) => Question.fromJson(i)).toList();
    return QuizResponse(
      quizId: json['quiz_id'],
      questions: questions,
    );
  }
}

class Question {
  final int id;
  final String questionText;
  final List<Option> options;

  Question(
      {required this.id, required this.questionText, required this.options});

  factory Question.fromJson(Map<String, dynamic> json) {
    var optionList = json['options'] as List;
    List<Option> options =
    optionList.map((i) => Option.fromJson(i)).toList();
    return Question(
      id: json['id'],
      questionText: json['question_text'],
      options: options,
    );
  }
}

class Option {
  final int id;
  final String optionText;
  final bool isCorrect; // <-- THÊM TRƯỜNG isCorrect

  Option(
      {required this.id, required this.optionText, required this.isCorrect});

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      id: json['id'],
      optionText: json['option_text'],
      isCorrect:
      json['is_correct'] ?? false, // Đọc giá trị is_correct từ JSON
    );
  }
}

// Model này có thể không cần thiết nữa nếu không có API submit
class QuizSubmitResponse {
  final int score;
  final int totalQuestions;

  QuizSubmitResponse({
    required this.score,
    required this.totalQuestions,
  });
}

// ===================================================================
// 2. API SERVICE (ĐÃ ĐƠN GIẢN HÓA)
// ===================================================================

class ApiService {
  final String _baseUrl = "http://127.0.0.1:8000";
  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<QuizResponse> startQuizSession(int topicId) async {
    final token = await _getToken();
    // if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$_baseUrl/quizzes/start_session'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'topic_id': topicId, 'num_questions': 5}),
    );

    if (response.statusCode == 200) {
      // Giả sử API trả về UTF8-encoded JSON
      return QuizResponse.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to load quiz: ${response.body}');
    }
  }

// Hàm submitQuiz không còn cần thiết cho việc chấm điểm
}

// ===================================================================
// 3. UI - TRANG KẾT QUẢ (ĐÃ ĐƠN GIẢN HÓA)
// ===================================================================
class QuizResultPage extends StatelessWidget {
  final int score;
  final int totalQuestions;

  const QuizResultPage(
      {Key? key, required this.score, required this.totalQuestions})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Kết Quả"),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false, // Ẩn nút back
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "HOÀN THÀNH!",
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700]),
              ),
              const SizedBox(height: 20),
              Text(
                "Số câu trả lời đúng của bạn",
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              Text(
                "$score/$totalQuestions",
                style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Quay lại trang trước đó
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text("Tuyệt vời!",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// 4. UI - TRANG LÀM BÀI (LOGIC CHẤM ĐIỂM MỚI)
// ===================================================================

class KiemTraPage extends StatefulWidget {
  final int topicId;

  const KiemTraPage({Key? key, required this.topicId}) : super(key: key);

  @override
  State<KiemTraPage> createState() => _KiemTraPageState();
}

class _KiemTraPageState extends State<KiemTraPage> {
  final ApiService _apiService = ApiService();
  late Future<QuizResponse> _quizFuture;
  final PageController _pageController = PageController();

  // Trạng thái của bài kiểm tra
  QuizResponse? _currentQuiz;
  int _currentQuestionIndex = 0;
  Map<int, int> _userAnswers = {}; // Lưu {questionId: selectedOptionId}

  @override
  void initState() {
    super.initState();
    _quizFuture = _apiService.startQuizSession(widget.topicId);
  }

  void _selectOption(int questionId, int optionId) {
    setState(() {
      _userAnswers[questionId] = optionId;
    });
  }

  // HÀM CHẤM ĐIỂM MỚI (CHẠY TRÊN CLIENT)
  void _submitQuiz() {
    if (_currentQuiz == null) return;

    int score = 0;
    // Lặp qua từng câu hỏi trong bài quiz
    for (var question in _currentQuiz!.questions) {
      // Tìm lựa chọn đúng của câu hỏi đó
      final correctOption =
      question.options.firstWhere((opt) => opt.isCorrect);

      // Kiểm tra xem người dùng có trả lời đúng không
      if (_userAnswers[question.id] == correctOption.id) {
        score++;
      }
    }

    // Điều hướng đến trang kết quả với điểm số đã tính
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizResultPage(
          score: score,
          totalQuestions: _currentQuiz!.questions.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Làm Bài Tập"),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: FutureBuilder<QuizResponse>(
        future: _quizFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi tải câu hỏi: ${snapshot.error}"));
          }
          if (snapshot.hasData) {
            _currentQuiz = snapshot.data!;
            final questions = _currentQuiz!.questions;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildProgressIndicator(questions.length),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentQuestionIndex = index;
                      });
                    },
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      return _buildQuestionPage(questions[index]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildNavigationButtons(questions.length),
                ),
              ],
            );
          }
          return const Center(child: Text("Không có dữ liệu"));
        },
      ),
    );
  }

  Widget _buildQuestionPage(Question question) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.questionText,
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ...question.options.map((option) {
                return _buildOptionTile(question.id, option);
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int totalQuestions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Câu ${_currentQuestionIndex + 1}/$totalQuestions",
          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / totalQuestions,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildOptionTile(int questionId, Option option) {
    bool isSelected = _userAnswers[questionId] == option.id;
    return InkWell(
      onTap: () => _selectOption(questionId, option.id),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.all(15.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                option.optionText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(int totalQuestions) {
    bool isFirstQuestion = _currentQuestionIndex == 0;
    bool isLastQuestion = _currentQuestionIndex == totalQuestions - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Nút Quay lại
        Opacity(
          opacity: isFirstQuestion ? 0.0 : 1.0,
          child: ElevatedButton(
            onPressed: isFirstQuestion
                ? null
                : () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        // Nút Tiếp theo / Nộp bài
        ElevatedButton(
          onPressed: () {
            if (isLastQuestion) {
              _submitQuiz();
            } else {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: Text(
            isLastQuestion ? "NỘP BÀI" : "TIẾP THEO",
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
