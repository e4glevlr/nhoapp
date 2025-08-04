import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lấy stream trạng thái xác thực
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng ký bằng email và mật khẩu
  Future<User?> signUp(String email, String password, String displayName) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      // Cập nhật tên hiển thị cho người dùng
      if (user != null) {
        await user.updateDisplayName(displayName);
        // Tạo một document mới cho người dùng trong Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'displayName': displayName,
          'email': email,
          // Thêm các trường khác nếu cần
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      // Xử lý các lỗi xác thực cụ thể
      print('Lỗi đăng ký: ${e.message}');
      return null;
    } catch (e) {
      // Xử lý các lỗi khác
      print('Đã xảy ra lỗi không mong muốn: $e');
      return null;
    }
  }

  // Đăng nhập bằng email và mật khẩu
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      // Xử lý các lỗi xác thực cụ thể
      print('Lỗi đăng nhập: ${e.message}');
      return null;
    } catch (e) {
      // Xử lý các lỗi khác
      print('Đã xảy ra lỗi không mong muốn: $e');
      return null;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print('Lỗi đăng xuất: $e');
    }
  }

  // Lấy người dùng hiện tại
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
