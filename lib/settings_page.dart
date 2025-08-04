import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  /// Hàm cập nhật cài đặt thông báo đẩy trên Firestore.
  /// Sử dụng `set` với `SetOptions(merge: true)` để đảm bảo an toàn:
  /// - Nếu object `settings` chưa tồn tại, nó sẽ được tạo.
  /// - Nếu object `settings` đã tồn tại, nó chỉ cập nhật hoặc thêm trường mới.
  Future<void> _updatePushNotificationSetting(String uid, bool isEnabled) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'settings': {
          'pushNotificationsEnabled': isEnabled,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      // Hiển thị lỗi cho người dùng nếu cập nhật thất bại
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật cài đặt: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin người dùng từ Provider
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.getCurrentUser();

    // Xử lý trường hợp người dùng chưa đăng nhậ
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Cài đặt")),
        body: Center(child: Text("Vui lòng đăng nhập để thay đổi cài đặt.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Cài đặt'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Lắng nghe real-time document của người dùng
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Hiển thị loading indicator khi đang chờ dữ liệu
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // Hiển thị lỗi nếu có
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }
          // Xử lý trường hợp không tìm thấy document
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Không tìm thấy thông tin người dùng.'));
          }

          // Lấy dữ liệu người dùng
          final userData = snapshot.data!.data() as Map<String, dynamic>;

          // Xử lý trường hợp người dùng mới chưa có object 'settings'
          // Nếu `userData['settings']` là null, nó sẽ trả về một map rỗng `{}`.
          final settings = userData['settings'] as Map<String, dynamic>? ?? {};
          
          // Lấy giá trị của switch. Nếu không tồn tại, mặc định là false.
          final bool isPushEnabled = settings['pushNotificationsEnabled'] ?? false;

          return ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              Text(
                'Thông báo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
              ),
              SizedBox(height: 10),
              // Sử dụng SwitchListTile để hiển thị cài đặt
              SwitchListTile(
                title: Text('Bật thông báo đẩy'),
                subtitle: Text('Nhận thông báo về tin tức và cập nhật quan trọng.'),
                value: isPushEnabled, // Giá trị của switch được lấy từ Firestore
                onChanged: (bool newValue) {
                  // Khi người dùng gạt switch, gọi hàm để cập nhật Firestore
                  _updatePushNotificationSetting(currentUser.uid, newValue);
                },
                activeColor: Colors.blue,
                secondary: Icon(Icons.notifications_active),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Bạn có thể thêm các cài đặt khác ở đây
            ],
          );
        },
      ),
    );
  }
}