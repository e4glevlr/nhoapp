import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Thêm import
import 'dart:ui'; // Thêm import
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'components/GlassmorphicToggle.dart';
import 'services/auth_service.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  final double cornerRadius = 16.0;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploading = false;
  // Toàn bộ logic xử lý dữ liệu của bạn được giữ nguyên
  Future<void> _changeAvatar() async {
    // ... logic giữ nguyên
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.getCurrentUser();
    if (user == null) return;

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        final storageRef = FirebaseStorage.instance.ref().child('avatars/${user.uid}');
        if (kIsWeb) {
          await storageRef.putData(await pickedFile.readAsBytes());
        } else {
          await storageRef.putFile(File(pickedFile.path));
        }
        final downloadUrl = await storageRef.getDownloadURL();
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoUrl': downloadUrl});
        await user.updatePhotoURL(downloadUrl);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật ảnh đại diện thành công!")));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi tải ảnh lên: $e")));
      } finally {
        if(mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _createUserDataIfMissing(User user) async {
    // ... logic giữ nguyên
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await userRef.get();
    if (!doc.exists) {
      try {
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? 'Người dùng mới',
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'learningStats': {'wordsLearned': 0, 'streakDays': 0, 'achievements': 0},
          'settings': {'pushNotificationsEnabled': true},
        });
      } catch (e) {
        print("Error creating user document: $e");
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.getCurrentUser();

    if (user == null) {
      // Vẫn cần một trang chờ cơ bản
      return const Scaffold(body: Center(child: Text("Không tìm thấy người dùng.")));
    }

    // ÁP DỤNG NỀN ĐỘNG CHO TOÀN BỘ TRANG
    return Scaffold(
        backgroundColor: Colors.transparent, // Nền trong suốt để thấy gradient
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            // Các trạng thái loading, error cần style lại để thấy trên nền tối
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return Center(child: Text("Lỗi: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return FutureBuilder(
                future: _createUserDataIfMissing(user),
                builder: (context, futureSnapshot) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text("Đang khởi tạo dữ liệu...", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
              );
            }
            final userData = snapshot.data!.data()!;
            final displayName = userData['displayName'] ?? 'Người dùng mới';
            final email = userData['email'] ?? '';
            final photoUrl = userData['photoUrl'] as String?;
            final stats = userData['learningStats'] as Map<String, dynamic>? ?? {};
            final wordsLearned = stats['wordsLearned'] ?? 0;
            final streakDays = stats['streakDays'] ?? 0;
            final achievements = stats['achievements'] ?? 0;

            return SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(context, displayName, email, photoUrl),
                  ),
                  SliverToBoxAdapter(
                    child: _buildStatsCard(wordsLearned, streakDays, achievements),
                  ),
                  SliverToBoxAdapter(
                    child: _buildOptionsList(context, authService),
                  ),
                ],
              ),
            );
          },
        ),
    );
  }

  // ----- CÁC WIDGET GIAO DIỆN ĐƯỢC STYLE LẠI -----

  Widget _buildHeader(BuildContext context, String name, String email, String? photoUrl) {
    // Bỏ container cũ, đặt trực tiếp lên nền gradient
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _changeAvatar,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage: (photoUrl != null) ? CachedNetworkImageProvider(photoUrl) : null,
                    child: (photoUrl == null && !_isUploading)
                        ? const Icon(Icons.person, size: 50, color: Colors.white70)
                        : null,
                  ),
                ),
                if (_isUploading) const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(int words, int streak, int achievements) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GlassmorphicContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.school_outlined, words.toString(), "Từ đã học"),
              _buildStatItem(Icons.local_fire_department_outlined, streak.toString(), "Ngày chuỗi"),
              _buildStatItem(Icons.star_border_outlined, achievements.toString(), "Thành tích"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    // Style lại với màu trắng
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 14)),
      ],
    );
  }

  Widget _buildOptionsList(BuildContext context, AuthService authService) {
    // Sử dụng GlassmorphicContainer
    return Padding(
      padding: const EdgeInsets.all(20),
      child:
      GlassmorphicContainer(
        child: Column(
          children: [
            _buildOptionItem(context, icon: Icons.person_outline, title: "Chỉnh sửa hồ sơ", onTap: () {}),
            Divider(color: Colors.white.withOpacity(0.15), height: 1),
            _buildOptionItem(context, icon: Icons.notifications_outlined, title: "Quản lý thông báo", onTap: () {}),
            Divider(color: Colors.white.withOpacity(0.15), height: 1),
            _buildOptionItem(context, icon: Icons.lock_outline, title: "Đổi mật khẩu", onTap: () {}),
            Divider(color: Colors.white.withOpacity(0.15), height: 1),
            _buildOptionItem(
              context,
              icon: Icons.logout,
              title: "Đăng xuất",
              color: const Color(0xFFFF7B7B), // Màu đỏ tươi hơn
              onTap: () async {
                await authService.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
    // Style lại ListTile
    final itemColor = color ?? Colors.white;
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Icon(icon, color: itemColor),
      title: Text(title, style: GoogleFonts.inter(color: itemColor)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withOpacity(0.7)),
      onTap: (onTap),
      splashColor: Colors.black.withOpacity(0.1),
    );
  }
}