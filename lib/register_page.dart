import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'home_page.dart'; // <-- THÊM IMPORT CHO TRANG CHỦ


class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  final _authService = AuthService(); // Khởi tạo AuthService

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Hàm xử lý logic đăng ký đã được cập nhật
  Future<void> _handleSignUp() async {
    // Kiểm tra xem tất cả các trường có trống không
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ tất cả các trường.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final displayName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

    // Gọi phương thức signUp mới
    final user = await _authService.signUp(
      _emailController.text,
      _passwordController.text,
      displayName,
    );

    if (mounted) {
      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thất bại. Email có thể đã tồn tại hoặc không hợp lệ.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // --- Style Definitions ---
    const Gradient backgroundGradient = LinearGradient(
      colors: [Color(0xFF68429C), Color(0xFF29ABE2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final BoxDecoration formContainerDecoration = BoxDecoration(
      color: Colors.white.withAlpha((255 * 0.1).round()),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha((255 * 0.3).round()),
          blurRadius: 25,
          offset: const Offset(0, 10),
        ),
      ],
      border: Border.all(color: Colors.white.withAlpha((255*0.1).round())),
    );

    const TextStyle titleStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white);
    const TextStyle subtitleStyle = TextStyle(fontSize: 14, color: Colors.white70);
    const TextStyle buttonTextStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white);
    const TextStyle logoTextStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18);
    const TextStyle labelStyle = TextStyle(color: Colors.white70);
    const TextStyle inputStyle = TextStyle(color: Colors.white);

    InputDecoration inputDecoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: labelStyle,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
      );
    }

    // --- Widget Tree ---
    return Scaffold(
      body: Stack( // <-- SỬ DỤNG STACK ĐỂ XẾP CHỒNG WIDGET
        children: [
          // NỘI DUNG GỐC (NỀN VÀ FORM)
          Container(
            decoration: const BoxDecoration(gradient: backgroundGradient),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: formContainerDecoration,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.1)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text('MY', style: logoTextStyle),
                          ),
                          const SizedBox(width: 16),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tạo tài khoản', style: titleStyle),
                              Text('Nhanh chóng & Bảo mật', style: subtitleStyle),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 24),

                      TextField(
                        controller: _lastNameController,
                        style: inputStyle,
                        decoration: inputDecoration('Họ'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _firstNameController,
                        style: inputStyle,
                        decoration: inputDecoration('Tên'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        style: inputStyle,
                        keyboardType: TextInputType.emailAddress,
                        decoration: inputDecoration('Email'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        style: inputStyle,
                        obscureText: true,
                        decoration: inputDecoration('Mật khẩu'),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.pinkAccent.withOpacity(0.8),
                          elevation: 8,
                          shadowColor: Colors.black.withOpacity(0.4),
                        ),
                        onPressed: _isLoading ? null : _handleSignUp,
                        child: _isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                            : const Text('Đăng ký', style: buttonTextStyle),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // NÚT QUAY LẠI MỚI
          Positioned(
            top: MediaQuery.of(context).padding.top, // Đặt dưới thanh trạng thái
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // Quay lại màn hình trước đó
                Navigator.of(context).pop();
              },
              tooltip: 'Quay lại',
            ),
          ),
        ],
      ),
    );
  }
}
