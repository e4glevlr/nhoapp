import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'components/GlassmorphicToggle.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';


class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _updatePushNotificationSetting(String uid, bool isEnabled) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'settings': {'pushNotificationsEnabled': isEnabled}
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật cài đặt: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.getCurrentUser();

    // Widget gốc là SafeArea để tránh các phần tử giao diện bị che khuất
    return SafeArea(
      child: Column(
        children: [
          // Header tùy chỉnh thay thế cho AppBar
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), // Thêm padding ngang để chữ không bị dính sát vào cạnh
              child: Text(
                  "Cài đặt",
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w600
                  )
              ),
            ),
          ),
          // Phần thân của trang cài đặt
          Expanded(
            child: currentUser == null
                ? _buildLoginPrompt()
                : _buildSettingsBody(currentUser),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          "Vui lòng đăng nhập để thay đổi cài đặt.",
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSettingsBody(User currentUser) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}', style: TextStyle(color: Colors.white70)));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Xử lý trường hợp không có dữ liệu
          return _buildSettingsContent(currentUser, true); // Mặc định là bật
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final settings = userData['settings'] as Map<String, dynamic>? ?? {};
        final bool isPushEnabled = settings['pushNotificationsEnabled'] ?? false;

        return _buildSettingsContent(currentUser, isPushEnabled);
      },
    );
  }

  Widget _buildSettingsContent(User currentUser, bool isPushEnabled) {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        Text(
          'Thông báo',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 16),
        GlassmorphicContainer(
          child: SwitchListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Bật thông báo đẩy',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Nhận thông báo về tin tức và cập nhật quan trọng.',
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7)),
            ),

            value: isPushEnabled,
            onChanged: (bool newValue) {
              _updatePushNotificationSetting(currentUser.uid, newValue);
            },
            activeColor: Colors.white,
            activeTrackColor: Colors.cyanAccent.withOpacity(0.7),
            inactiveThumbColor: Colors.white70,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            secondary: Icon(Icons.notifications_active_outlined, color: Colors.white),
          ),
        ),


      ],
    );
  }
}