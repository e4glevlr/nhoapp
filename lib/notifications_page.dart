import 'package:flutter/material.dart';

/// Một trang giữ chỗ (placeholder) đơn giản cho màn hình thông báo.
/// 
/// Hiển thị một icon và một dòng chữ ở giữa màn hình để thông báo
/// cho người dùng rằng hiện tại chưa có thông báo nào.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        // Tùy chọn: làm cho AppBar trông phẳng hơn để hợp với trang trống
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon để biểu thị trạng thái trống
            Icon(
              Icons.notifications_off_outlined,
              size: 80, // Kích thước lớn để dễ nhìn
              color: Colors.grey[400], // Màu xám nhẹ để không quá nổi bật
            ),
            const SizedBox(height: 20), // Khoảng cách giữa icon và text
            // Dòng chữ thông báo
            Text(
              'Chưa có thông báo nào',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}