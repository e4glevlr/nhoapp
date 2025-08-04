import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Thêm import này
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Import các trang khác và service
import 'services/auth_service.dart';
// import 'edit_profile_page.dart'; // Trang này bạn sẽ tạo sau

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploading = false;

  // Hàm để xử lý việc chọn và tải ảnh lên
  Future<void> _changeAvatar() async {
    // Kiểm tra widget còn tồn tại không
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    // *** SỬA ĐỔI Ở ĐÂY ***
    final user = authService.getCurrentUser();
    if (user == null) return;

    final imagePicker = ImagePicker();
    // Cho người dùng chọn ảnh từ thư viện
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      try {
        // Tạo tham chiếu đến Firebase Storage
        final storageRef = FirebaseStorage.instance.ref().child('avatars/${user.uid}');

        // *** LOGIC XỬ LÝ ĐA NỀN TẢNG (WEB VÀ MOBILE) ***
        if (kIsWeb) {
          // Nếu là web, đọc dữ liệu ảnh và dùng putData
          await storageRef.putData(await pickedFile.readAsBytes());
        } else {
          // Nếu là mobile, dùng putFile
          await storageRef.putFile(File(pickedFile.path));
        }

        // Lấy URL tải xuống của ảnh
        final downloadUrl = await storageRef.getDownloadURL();

        // Cập nhật URL vào Firestore và FirebaseAuth
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'photoUrl': downloadUrl,
        });
        await user.updatePhotoURL(downloadUrl);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật ảnh đại diện thành công!")),
        );

      } catch (e) {
        // In lỗi chi tiết ra console để gỡ lỗi
        print("Lỗi chi tiết khi tải ảnh lên: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi tải ảnh lên: $e")),
        );
      } finally {
        if(mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  // *** HÀM MỚI: Tự động tạo dữ liệu người dùng nếu thiếu ***
  Future<void> _createUserDataIfMissing(User user) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await userRef.get();

    // Chỉ tạo nếu document thực sự chưa tồn tại
    if (!doc.exists) {
      print('User document not found for ${user.uid}. Creating one...');
      try {
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? 'Người dùng mới',
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'learningStats': {
            'wordsLearned': 0,
            'streakDays': 0,
            'achievements': 0,
          },
          'settings': {
            'pushNotificationsEnabled': true,
          },
        });
      } catch (e) {
        print("Error creating user document: $e");
        // Có thể hiển thị lỗi cho người dùng ở đây nếu cần
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    // *** SỬA ĐỔI Ở ĐÂY ***
    final user = authService.getCurrentUser();

    if (user == null) {
      // Trường hợp hiếm gặp, nhưng nên có để phòng lỗi
      return const Scaffold(body: Center(child: Text("Không tìm thấy người dùng.")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      // Sử dụng StreamBuilder để lắng nghe dữ liệu người dùng real-time
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi: ${snapshot.error}"));
          }

          // *** LOGIC SỬA LỖI NẰM Ở ĐÂY ***
          if (!snapshot.hasData || !snapshot.data!.exists) {
            // Nếu không tìm thấy document, gọi hàm tạo dữ liệu
            // và hiển thị màn hình loading trong lúc chờ.
            return FutureBuilder(
              future: _createUserDataIfMissing(user),
              builder: (context, futureSnapshot) {
                // Sau khi hàm tạo dữ liệu chạy xong, StreamBuilder sẽ tự động
                // nhận dữ liệu mới và vẽ lại UI, nên chỉ cần hiển thị loading.
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Đang khởi tạo dữ liệu người dùng..."),
                    ],
                  ),
                );
              },
            );
          }

          // Lấy dữ liệu từ snapshot
          final userData = snapshot.data!.data()!;
          final displayName = userData['displayName'] ?? 'Người dùng mới';
          final email = userData['email'] ?? '';
          final photoUrl = userData['photoUrl'] as String?;

          // Lấy dữ liệu học tập, với giá trị mặc định là 0
          final stats = userData['learningStats'] as Map<String, dynamic>? ?? {};
          final wordsLearned = stats['wordsLearned'] ?? 0;
          final streakDays = stats['streakDays'] ?? 0;
          final achievements = stats['achievements'] ?? 0;

          return CustomScrollView(
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
          );
        },
      ),
    );
  }

  // Widget xây dựng phần Header màu xanh
  Widget _buildHeader(BuildContext context, String name, String email, String? photoUrl) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
      decoration: const BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _changeAvatar,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  // Sử dụng CachedNetworkImage để tải và cache ảnh, hiển thị placeholder
                  backgroundImage: (photoUrl != null)
                      ? CachedNetworkImageProvider(photoUrl)
                      : null,
                  child: (photoUrl == null && !_isUploading)
                      ? const Icon(Icons.person, size: 50, color: Colors.blue)
                      : null,
                ),
                if (_isUploading) const CircularProgressIndicator(),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Widget xây dựng phần thẻ thống kê
  Widget _buildStatsCard(int words, int streak, int achievements) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.school_outlined, words.toString(), "Từ đã học", Colors.blue),
          _buildStatItem(Icons.local_fire_department_outlined, streak.toString(), "Ngày chuỗi", Colors.orange),
          _buildStatItem(Icons.star_border_outlined, achievements.toString(), "Thành tích", Colors.amber),
        ],
      ),
    );
  }

  // Widget cho mỗi mục thống kê
  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  // Widget xây dựng danh sách các tùy chọn
  Widget _buildOptionsList(BuildContext context, AuthService authService) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _buildOptionItem(
            context,
            icon: Icons.person_outline,
            title: "Chỉnh sửa hồ sơ",
            onTap: () {
              // TODO: Điều hướng đến trang EditProfilePage
              // Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage()));
            },
          ),
          _buildOptionItem(
            context,
            icon: Icons.notifications_outlined,
            title: "Quản lý thông báo",
            onTap: () {},
          ),
          _buildOptionItem(
            context,
            icon: Icons.lock_outline,
            title: "Đổi mật khẩu",
            onTap: () {},
          ),
          _buildOptionItem(
            context,
            icon: Icons.logout,
            title: "Đăng xuất",
            color: Colors.red,
            onTap: () async {
              await authService.signOut();
              // AuthWrapper sẽ tự động xử lý chuyển hướng
            },
          ),
        ],
      ),
    );
  }

  // Widget cho mỗi mục tùy chọn
  Widget _buildOptionItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey[700]),
      title: Text(title, style: TextStyle(color: color ?? Colors.black87)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
