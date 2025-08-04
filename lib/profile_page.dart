import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    // Sử dụng Provider để lấy AuthService và người dùng hiện tại
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = Provider.of<User?>(context);

    // Nếu người dùng chưa đăng nhập, hiển thị thông báo
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Hồ sơ'),
        ),
        body: Center(
          child: Text("Vui lòng đăng nhập để xem hồ sơ."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Hồ sơ của bạn'),
        actions: [
          // Nút đăng xuất
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              // Gọi hàm signOut từ AuthService
              await authService.signOut();
              // Sau khi đăng xuất, có thể bạn muốn điều hướng người dùng về trang đăng nhập
              // Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => LoginPage()), (route) => false);
            },
            tooltip: 'Đăng xuất',
          )
        ],
      ),
      // Sử dụng FutureBuilder để lấy dữ liệu từ Firestore
      body: FutureBuilder<DocumentSnapshot>(
        // Future là hàm lấy document của người dùng từ collection 'users' bằng UID
        future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          
          // 1. Trong khi chờ dữ liệu, hiển thị vòng tròn loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          // 2. Nếu có lỗi, hiển thị thông báo lỗi
          if (snapshot.hasError) {
            return Center(child: Text("Đã xảy ra lỗi: ${snapshot.error}"));
          }

          // 3. Nếu không có dữ liệu hoặc document không tồn tại
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("Không tìm thấy thông tin người dùng."));
          }

          // 4. Nếu có dữ liệu, hiển thị thông tin người dùng
          if (snapshot.hasData) {
            // Ép kiểu dữ liệu nhận được thành Map<String, dynamic>
            Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
            String displayName = userData['displayName'] ?? 'Chưa có tên';
            String email = userData['email'] ?? 'Chưa có email';

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    ),
                    SizedBox(height: 20),
                    Text(
                      displayName,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      email,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () async {
                        await authService.signOut();
                      },
                      child: Text('Đăng xuất'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      ),
                    )
                  ],
                ),
              ),
            );
          }

          // Trường hợp mặc định (không nên xảy ra)
          return Center(child: Text("Có lỗi xảy ra"));
        },
      ),
    );
  }
}