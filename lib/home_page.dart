import 'package:flutter/material.dart';
import 'chat_page.dart';
// import 'voice_page.dart'; // Bạn không cần import voice_page nếu không dùng nữa
import 'test_page.dart'; // Đảm bảo import này đúng
import 'documents_page.dart'; // <<-- thêm import

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar with settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bạn có thể thêm các nút hoặc icon vào đây
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),

                      // Doctor AI Card - Chat
                      Container(
                        padding: EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Nhắn tin cùng ALDA",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "Cùng ALDA nhắn tin luyện tập nhé",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatPage(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 30,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      "Bắt đầu Chat",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Image.asset(
                                  'images/robot.png', // Make sure to have this image in your assets
                                  width: 100,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                                Positioned(
                                  top: 0,
                                  right: -10,
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.pink,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Hi!",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 30),

                      // Voice AI Card - ĐÃ SỬA ĐỔI
                      Container(
                        padding: EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Trò truyện cùng ALDA",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "Cùng ALDA trao đổi trò chuyện nhé",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          // --- THAY ĐỔI Ở ĐÂY ---
                                          builder:
                                              (context) =>
                                                  TestPage(), // Chuyển đến TestPage
                                          // builder: (context) => VoiceChatPage(), // Code cũ
                                          // ---------------------
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 30,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      "Bắt đầu trò truyện",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(Icons.mic, size: 80, color: Colors.blue),
                                Positioned(
                                  top: 0,
                                  right: -10,
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Talk!",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 30),

                      // Emergency Services
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            TestPage(), // Nút này cũng đang trỏ đến TestPage
                                  ),
                                );
                              },
                              child: _buildEmergencyCard(
                                "Kiểm tra",
                                "123",
                                Colors.green[100]!,
                                Icons.book,
                                Colors.green,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _buildEmergencyCard(
                              "Lịch học",
                              "112",
                              Colors.blue[100]!,
                              Icons.calendar_month_outlined,
                              Colors.blue,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DocumentManagerPage(),
                                  ),
                                );
                              },
                              child: _buildEmergencyCard(
                                "Dữ liệu",
                                "108",
                                Colors.orange[100]!,
                                Icons.image_sharp,
                                Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(
                        height: 30,
                      ), // Giảm khoảng cách để phù hợp với nội dung mới
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Navigation Bar
            Container(
              padding: EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    Icons.home_outlined,
                    "Trang chủ",
                    Colors.green,
                    true,
                  ),
                  _buildNavItem(
                    Icons.person_outlined,
                    "Hồ sơ",
                    Colors.blue,
                    false,
                  ), // Thêm nút voice ở navigation bar
                  _buildNavItem(
                    Icons.notifications_outlined,
                    "Thông báo",
                    Colors.yellow,
                    false,
                  ),
                  _buildNavItem(
                    Icons.settings_outlined,
                    "Cài đặt",
                    Colors.grey,
                    false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(
    String title,
    String number,
    Color bgColor,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center, // Căn giữa text nếu dài
          ),
          SizedBox(height: 5),
          Text(
            number,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    Color color,
    bool isActive,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? color : Colors.grey,
          size: 24,
        ), // Thay đổi màu icon dựa trên isActive
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color:
                isActive
                    ? color
                    : Colors.grey, // Thay đổi màu text dựa trên isActive
            fontSize: 12,
            fontWeight:
                isActive
                    ? FontWeight.bold
                    : FontWeight.normal, // Làm đậm nếu active
          ),
        ),
      ],
    );
  }
}
