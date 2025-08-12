import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'components/GlassmorphicToggle.dart'; // Giả định bạn có file này
import 'services/auth_service.dart';      // Giả định bạn có file này

// Thêm các import cần thiết
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_cropper/image_cropper.dart'; // MỚI: Import thư viện cropper


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  final double cornerRadius = 16.0;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploading = false;
  String? _localAvatarPath;

  @override
  void initState() {
    super.initState();
    _loadSavedAvatar();
  }

  Future<void> _loadSavedAvatar() async {
    if (kIsWeb) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final avatarFile = File(p.join(appDir.path, 'local_avatar.png'));
      if (await avatarFile.exists()) {
        setState(() {
          _localAvatarPath = avatarFile.path;
        });
      }
    } catch(e) {
      print("Lỗi khi tải ảnh đã lưu: $e");
    }
  }

  /// Mở thư viện, cho phép người dùng chọn, cắt và lưu ảnh đại diện.
  Future<void> _changeAvatar() async {
    if (!mounted) return;

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      // MỚI: Gọi giao diện cắt ảnh
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Cắt ảnh',
              toolbarColor: Colors.deepOrange,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: true, // Khóa tỉ lệ hình vuông
              aspectRatioPresets: [
                CropAspectRatioPreset.square, // Chỉ cho phép cắt hình vuông
              ]),
          IOSUiSettings(
            title: 'Cắt ảnh',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
        ],
      );

      // Nếu người dùng đã cắt ảnh (không phải hủy bỏ)
      if (croppedFile != null) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Tính năng lưu ảnh chưa hỗ trợ trên web.")));
          return;
        }

        setState(() => _isUploading = true);
        try {
          final appDir = await getApplicationDocumentsDirectory();
          const fileName = 'local_avatar.png';
          final savedAvatarPath = p.join(appDir.path, fileName);

          // Lưu file đã được cắt
          await File(croppedFile.path).copy(savedAvatarPath);

          final imageProvider = FileImage(File(savedAvatarPath));
          await imageProvider.evict(); // Xóa cache

          setState(() {
            _localAvatarPath = savedAvatarPath;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Cập nhật ảnh đại diện thành công!")));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi lưu ảnh: $e")));
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      }
    }
  }

  /// Tạo dữ liệu người dùng trên Firestore nếu chưa tồn tại.
  Future<void> _createUserDataIfMissing(User user) async {
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
        print("Lỗi tạo dữ liệu người dùng: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.getCurrentUser();

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Không tìm thấy người dùng.")));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _localAvatarPath == null) {
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

  /// Widget xây dựng phần header của trang cá nhân.
  Widget _buildHeader(BuildContext context, String name, String email, String? photoUrl) {
    ImageProvider? backgroundImage;

    if (_localAvatarPath != null) {
      backgroundImage = FileImage(File(_localAvatarPath!));
    }
    else if (photoUrl != null) {
      backgroundImage = CachedNetworkImageProvider(photoUrl);
    }

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
                    backgroundImage: backgroundImage,
                    child: (backgroundImage == null && !_isUploading)
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

  // Các widget con còn lại không thay đổi
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GlassmorphicContainer(
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
              color: const Color(0xFFFF7B7B),
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
