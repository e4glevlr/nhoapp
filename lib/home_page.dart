import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'chat_page.dart';
import 'test_page.dart';
import 'documents_page.dart';
import 'profile_page.dart';
import 'notifications_page.dart';
import 'settings_page.dart';
import 'schedule_page.dart';
import 'voice_page.dart';
import 'helpers/navigation_helper.dart';
import 'components/GlassmorphicToggle.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALDA App',
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}


class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  // 1. Đơn giản hóa AnimationController
  // Controller này giờ chỉ cần chạy từ 0.0 đến 1.0 và ngược lại để điều khiển opacity.
  late AnimationController _controller;

  final List<Widget> _pages = [
    HomePageContent(),
    ProfilePage(),
    NotificationsPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // Thời gian chuyển đổi giữa 2 màu
    )..repeat(reverse: true); // Lặp lại và đảo ngược (mờ dần -> hiện rõ -> mờ dần...)

    // 2. Xóa các TweenSequence không cần thiết
    // _topAlignmentAnimation và _bottomAlignmentAnimation đã được loại bỏ.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 3. Dùng Stack để xếp chồng các lớp gradient và UI
    return Stack(
      children: [
        // Lớp Gradient 1 (nền cố định)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6a11cb), Color(0xFF2575fc)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // Lớp Gradient 2 (lớp này sẽ mờ đi và hiện ra)
        FadeTransition(
          // Dùng FadeTransition để animate opacity một cách hiệu quả
          opacity: _controller,
          child: Container(
            decoration: const BoxDecoration(
              // Bạn có thể đổi bộ màu này để tạo hiệu ứng mong muốn
              gradient: LinearGradient(
                colors: [Color(0xFFff7ab6), Color(0xFF6ea8fe)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
        ),

        // Lớp UI (Scaffold) nằm trên cùng
        Scaffold(
          backgroundColor: Colors.transparent, // QUAN TRỌNG: Phải trong suốt để thấy nền
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: Container(
              key: ValueKey<int>(_selectedIndex),
              child: _pages[_selectedIndex],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Hồ sơ'),
              BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Thông báo'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Cài đặt'),
            ],
            currentIndex: _selectedIndex,
            backgroundColor: Colors.white.withOpacity(0.1),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.6),
            elevation: 0,
            onTap: _onItemTapped,
          ),
        ),
      ],
    );
  }
}


class HomePageContent extends StatelessWidget {
  const HomePageContent({Key? key}) : super(key: key);

  Widget _buildChatCard(BuildContext context) {
    return GlassmorphicContainer(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Nhắn tin cùng ALDA", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text("Cùng ALDA nhắn tin luyện tập nhé.", style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                  const SizedBox(height: 20),
                  PrimaryCtaButton(
                    text: "Bắt đầu Chat",
                    onPressed: () => navigateToPageWithFade(context, const ChatPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Image.asset(
              'images/robot.png',
              width: 90, height: 90,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.smart_toy_outlined, size: 80, color: Colors.white.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTalkCard(BuildContext context) {
    return GlassmorphicContainer(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Trò chuyện cùng ALDA", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text("Cùng ALDA trao đổi và trò chuyện.", style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                  const SizedBox(height: 20),
                  PrimaryCtaButton(
                    text: "Bắt đầu trò chuyện",
                    onPressed: () => navigateToPageWithFade(context, const VoiceChatPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.mic_rounded, size: 70, color: Colors.white.withOpacity(0.9)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildFeatureCard(context, title: "Kiểm tra", icon: Icons.school_outlined, onTap: () => navigateToPageWithFade(context, const TestPage()))),
        const SizedBox(width: 12),
        Expanded(child: _buildFeatureCard(context, title: "Lịch học", icon: Icons.calendar_month_outlined, onTap: () => navigateToPageWithFade(context, const SchedulePage()))),
        const SizedBox(width: 12),
        Expanded(child: _buildFeatureCard(context, title: "Dữ liệu", icon: Icons.folder_copy_outlined, onTap: () => navigateToPageWithFade(context, const DocumentManagerPage()))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ScrollConfiguration(
          behavior: NoScrollbarBehavior(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: constraints.maxWidth > 768
                      ? _buildWideLayout(context)
                      : _buildNarrowLayout(context),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Xin chào!", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        Text("Hãy bắt đầu ngày mới tuyệt vời.", style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 30),
        _buildChatCard(context),
        const SizedBox(height: 24),
        _buildTalkCard(context),
        const SizedBox(height: 30),
        _buildFeatureRow(context),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Xin chào!", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        Text("Hãy bắt đầu ngày mới tuyệt vời.", style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withOpacity(0.8))),
        const SizedBox(height: 30),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildChatCard(context)),
            const SizedBox(width: 24),
            Expanded(child: _buildTalkCard(context)),
          ],
        ),
        const SizedBox(height: 30),
        _buildFeatureRow(context),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}



class PrimaryCtaButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const PrimaryCtaButton({Key? key, required this.text, required this.onPressed}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFff7ab6), Color(0xFF6ea8fe)]),
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [BoxShadow(color: const Color(0xFF6ea8fe).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 5)), BoxShadow(color: const Color(0xFFff7ab6).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 5))]
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
        child: Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF06203a))),
      ),
    );
  }
}