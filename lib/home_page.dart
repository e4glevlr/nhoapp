import 'package:flutter/material.dart';
import 'test.dart';
import 'memory.dart';
import 'time_management.dart';
import 'chat_page.dart';
import 'voice_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomePageBody(),
    ProfilePage(),
    NotificationPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            InkWell(
              onTap: () => _onItemTapped(0),
              child: _buildNavItem(Icons.home_outlined, "Trang chủ", 0),
            ),
            InkWell(
              onTap: () => _onItemTapped(1),
              child: _buildNavItem(Icons.person_outlined, "Hồ sơ", 1),
            ),
            InkWell(
              onTap: () => _onItemTapped(2),
              child: _buildNavItem(Icons.notifications_outlined, "Thông báo", 2),
            ),
            InkWell(
              onTap: () => _onItemTapped(3),
              child: _buildNavItem(Icons.settings_outlined, "Cài đặt", 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isActive = _selectedIndex == index;
    final color = isActive ? Colors.green : Colors.grey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class HomePageBody extends StatelessWidget {
  const HomePageBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // App Bar with settings
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    const SizedBox(height: 20),

                    // Doctor AI Card - Chat
//----------------------------------------------------------------------------------------------------
                    Container(
                      padding: const EdgeInsets.all(20),
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
                                const Text(
                                  "Nhắn tin cùng Nhớ",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Cùng Nhớ nhắn tin  chia sẻ và thấu hiểu nhau",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ChatPage()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.pink,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    "ngon!",
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

                    const SizedBox(height: 30),

                    // Voice AI Card - THÊM MỚI
//----------------------------------------------------------------------------------------------------
                    Container(
                      padding: const EdgeInsets.all(20),
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
                                const Text(
                                  "Trò truyện cùng Nhớ",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Cùng Nhớ trao đổi trò chuyện để thấu hiểu nhau",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const VoiceChatPage()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
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
                              const Icon(
                                Icons.mic,
                                size: 80,
                                color: Colors.blue,
                              ),
                              Positioned(
                                top: 0,
                                right: -10,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
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

                    const SizedBox(height: 30),

                    // Emergency Services
//----------------------------------------------------------------------------------------------------
                    Row(
                      children: [
                        // Thẻ 1: Kiểm tra
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              print("Chuyển đến trang Kiểm tra");
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const KiemTraPage(topicId: 0)), // Thay bằng trang của bạn
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
                        const SizedBox(width: 10),

                        // Thẻ 2: Quản lý thời gian
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              print("Chuyển đến trang Quản lý thời gian");
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const QuanLyThoiGianPage()), // Thay bằng trang của bạn
                              );
                            },
                            child: _buildEmergencyCard(
                              "Quản lý thời gian",
                              "112",
                              Colors.blue[100]!,
                              Icons.calendar_month_outlined,
                              Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Thẻ 3: Kỉ niệm
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              print("Chuyển đến trang Kỉ niệm");
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const KiNiemPage()), // Thay bằng trang của bạn
                              );
                            },
                            child: _buildEmergencyCard(
                              "Kỉ niệm",
                              "180",
                              Colors.orange[100]!,
                              Icons.image_sharp,
                              Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30), // Giảm khoảng cách để phù hợp với nội dung mới
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard(String title, String number, Color bgColor, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            number,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(""),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_note_outlined),
            onPressed: () {
              // Logic để chỉnh sửa hồ sơ
            },
            tooltip: "Chỉnh sửa",
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildProfileHeader(),
          SizedBox(height: 20),
          _buildStatisticsCard(),
          SizedBox(height: 20),
          _buildOptionsMenu(),
        ],
      ),
    );
  }

  // Widget cho phần đầu của trang hồ sơ (avatar, tên, email)
  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            // Thay bằng ảnh đại diện của người dùng
            // Bạn có thể sử dụng NetworkImage('url') nếu có link ảnh
            backgroundImage: NetworkImage('https://scontent.fhan5-9.fna.fbcdn.net/v/t1.6435-1/33154404_590036248019172_2375602860172771328_n.jpg?stp=dst-jpg_s200x200_tt6&_nc_cat=109&ccb=1-7&_nc_sid=e99d92&_nc_ohc=w20FtAEwwhMQ7kNvwGeOvql&_nc_oc=Adnzjb9BvCmRjTtKp5ShxiUyrlnCNCG19Tk1eH4NmhwQ8oECpG1uJOrQPG3CUFc1_Qg&_nc_zt=24&_nc_ht=scontent.fhan5-9.fna&_nc_gid=0acmGx0DB2IakstazBLh4Q&oh=00_AfR65d8EaHBqxUMslmTW2SfI-zPkrhv9xE9ooWUCjMrEvg&oe=68AB0423'),
          ),
          SizedBox(height: 12),
          Text(
            "Nguyễn Mạnh Hùng", // Tên người dùng
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "hung.one.oh.one@gmail.com", // Email người dùng
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị các thẻ thống kê
  Widget _buildStatisticsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.spellcheck, "1,250", "Từ đã học"),
              _buildStatItem(Icons.local_fire_department, "35", "Ngày chuỗi"),
              _buildStatItem(Icons.star, "15", "Thành tích"),
            ],
          ),
        ),
      ),
    );
  }

  // Widget cho một mục thống kê
  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 30),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // Widget cho menu các tùy chọn
  Widget _buildOptionsMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          _buildOptionItem(
            Icons.person_outline,
            "Chỉnh sửa hồ sơ",
                () {
              // Logic chuyển trang
            },
          ),
          _buildOptionItem(
            Icons.notifications_none_outlined,
            "Quản lý thông báo",
                () {
              // Logic chuyển trang
            },
          ),
          _buildOptionItem(
            Icons.lock_outline,
            "Đổi mật khẩu",
                () {
              // Logic chuyển trang
            },
          ),
          SizedBox(height: 10),
          Divider(),
          SizedBox(height: 10),
          _buildOptionItem(
            Icons.logout,
            "Đăng xuất",
                () {
              // Logic đăng xuất
            },
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  // Widget cho một tùy chọn trong menu
  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap, {Color color = Colors.black87}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  // Dữ liệu mẫu
  final List<Map<String, dynamic>> _notifications = [
    {'title': 'Chuỗi ngày học của bạn đã đạt 7 ngày!', 'time': '15 phút trước', 'isRead': false, 'icon': Icons.local_fire_department, 'color': Colors.orange},
    {'title': 'Bạn vừa mở khóa thành tích "Học giả"', 'time': '1 giờ trước', 'isRead': false, 'icon': Icons.star, 'color': Colors.amber},
    {'title': 'Nhắc nhở: Đã đến lúc ôn tập từ vựng', 'time': 'Hôm qua', 'isRead': true, 'icon': Icons.book, 'color': Colors.blue},
    {'title': 'Chào mừng bạn đến với ứng dụng!', 'time': '2 ngày trước', 'isRead': true, 'icon': Icons.info, 'color': Colors.green},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Thông Báo"),
        backgroundColor: Colors.yellow[700],
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var notif in _notifications) {
                  notif['isRead'] = true;
                }
              });
            },
            child: Text(
              "Đọc tất cả",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(10.0),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            color: notif['isRead'] ? Colors.white : Colors.yellow[50],
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              leading: CircleAvatar(
                backgroundColor: notif['color'].withOpacity(0.2),
                child: Icon(notif['icon'], color: notif['color']),
              ),
              title: Text(
                notif['title'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Text(
                  notif['time'],
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              onTap: () {
                setState(() {
                  notif['isRead'] = true;
                });
              },
            ),
          );
        },
      ),
    );
  }
}


class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text("Cài Đặt"),
        backgroundColor: Colors.grey[700],
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader("Tài khoản"),
          _buildOptionTile(Icons.person, "Thông tin cá nhân", () {}),
          _buildOptionTile(Icons.lock, "Bảo mật", () {}),

          _buildSectionHeader("Thông báo"),
          SwitchListTile(
            title: Text("Thông báo đẩy"),
            subtitle: Text("Nhận thông báo về lịch học và tiến độ"),
            value: _pushNotifications,
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
            },
            secondary: Icon(Icons.notifications),
            activeColor: Colors.teal,
          ),

          _buildSectionHeader("Giao diện"),
          SwitchListTile(
            title: Text("Chế độ tối (Dark Mode)"),
            subtitle: Text("Sử dụng giao diện tối để bảo vệ mắt"),
            value: _darkMode,
            onChanged: (value) {
              setState(() {
                _darkMode = value;
              });
            },
            secondary: Icon(Icons.dark_mode),
            activeColor: Colors.teal,
          ),
          _buildOptionTile(Icons.language, "Ngôn ngữ", () {}),

          _buildSectionHeader("Khác"),
          _buildOptionTile(Icons.info_outline, "Về chúng tôi", () {}),
          _buildOptionTile(Icons.help_outline, "Trợ giúp & Phản hồi", () {}),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
