import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // Cần cho hiệu ứng

/// Một trang hiển thị khi chưa có thông báo, được thiết kế nhất quán
/// với phong cách glassmorphism và nền gradient động của ứng dụng.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

// Chuyển thành StatefulWidget để thêm animation cho nền
class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    // Áp dụng nền gradient động cho toàn bộ trang
    return Scaffold(
      backgroundColor: Colors.transparent, // Nền trong suốt
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Style lại icon cho phù hợp với nền tối
            Icon(
              Icons.notifications_off_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 20),
            // Style lại text
            Text(
              'Chưa có thông báo nào',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}