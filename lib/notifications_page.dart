// lib/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    // --- THAY ĐỔI: Loại bỏ Scaffold và AppBar ---
    return SafeArea(
      child: Column(
        children: [
          // Header tùy chỉnh thay thế cho AppBar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text("Thông báo", style: GoogleFonts.inter(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  const SizedBox(height: 20),
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
          ),
        ],
      ),
    );
  }
}