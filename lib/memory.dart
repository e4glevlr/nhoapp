import 'package:flutter/material.dart';

class KiNiemPage extends StatelessWidget {
  const KiNiemPage({Key? key}) : super(key: key);

  // Dữ liệu mẫu
  final List<Map<String, String>> memories = const [
    {'image': 'images/robot.png', 'title': 'Ngày đầu tiên', 'date': '20/07/2023'},
    {'image': 'images/icon.png', 'title': 'Chuyến đi Đà Lạt', 'date': '15/08/2023'},
    {'image': 'images/robot.png', 'title': 'Sinh nhật vui vẻ', 'date': '01/09/2023'},
    {'image': 'images/icon.png', 'title': 'Kỉ niệm 1 năm', 'date': '10/10/2023'},
    {'image': 'images/robot.png', 'title': 'Mùa đông Hà Nội', 'date': '25/12/2023'},
    {'image': 'images/icon.png', 'title': 'Tết Nguyên Đán', 'date': '10/02/2024'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        title: Text("Album Kỉ Niệm"),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(10.0),
        // Xác định số cột và khoảng cách giữa các item
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 cột
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          childAspectRatio: 0.8, // Tỷ lệ chiều rộng/chiều cao
        ),
        itemCount: memories.length,
        itemBuilder: (context, index) {
          final memory = memories[index];
          return Card(
            elevation: 4,
            clipBehavior: Clip.antiAlias, // Để bo tròn ảnh bên trong
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Phần ảnh
                Expanded(
                  child: Image.asset(
                    memory['image']!,
                    fit: BoxFit.cover,
                  ),
                ),
                // Phần tiêu đề và ngày tháng
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memory['title']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        memory['date']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Logic để thêm kỉ niệm mới
        },
        child: Icon(Icons.add_a_photo, color: Colors.white),
        backgroundColor: Colors.orange,
        tooltip: "Thêm kỉ niệm",
      ),
    );
  }
}
