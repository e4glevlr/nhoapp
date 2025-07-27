import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Thêm gói intl để định dạng ngày tháng

// Model đơn giản cho một công việc
class Task {
  final String title;
  final String category;
  final Color categoryColor;
  bool isCompleted;

  Task({
    required this.title,
    required this.category,
    required this.categoryColor,
    this.isCompleted = false,
  });
}

// Chuyển thành StatefulWidget để quản lý trạng thái của các task (đã hoàn thành hay chưa)
class QuanLyThoiGianPage extends StatefulWidget {
  const QuanLyThoiGianPage({Key? key}) : super(key: key);

  @override
  State<QuanLyThoiGianPage> createState() => _QuanLyThoiGianPageState();
}

class _QuanLyThoiGianPageState extends State<QuanLyThoiGianPage> {
  // Danh sách các công việc mẫu
  final List<Task> _tasks = [
    Task(title: "Hoàn thành báo cáo tuần", category: "Công việc", categoryColor: Colors.orange),
    Task(title: "Đi siêu thị mua đồ ăn", category: "Cá nhân", categoryColor: Colors.green),
    Task(title: "Tập thể dục 30 phút", category: "Sức khỏe", categoryColor: Colors.blue),
    Task(title: "Gọi điện cho gia đình", category: "Cá nhân", categoryColor: Colors.green, isCompleted: true),
    Task(title: "Đọc 1 chương sách", category: "Học tập", categoryColor: Colors.purple),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // Màu nền nhẹ nhàng
      appBar: AppBar(
        title: Text("Quản Lý Thời Gian"),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeader(),
          SizedBox(height: 20),
          _buildTaskList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Logic để thêm công việc mới
        },
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blueAccent,
        tooltip: "Thêm công việc",
      ),
    );
  }

  // Widget hiển thị ngày tháng hiện tại
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMMEEEEd('vi').format(DateTime.now()), // Hiển thị ngày đầy đủ bằng tiếng Việt
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Công việc hôm nay",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị danh sách công việc
  Widget _buildTaskList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "DANH SÁCH",
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 10),
        // Sử dụng ListView.builder để hiệu quả hơn nếu danh sách dài
        ListView.builder(
          shrinkWrap: true, // Quan trọng khi đặt ListView trong một ListView khác
          physics: NeverScrollableScrollPhysics(), // Tắt cuộn của ListView con
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            final task = _tasks[index];
            return _buildTaskItem(task);
          },
        ),
      ],
    );
  }

  // Widget cho một item công việc
  Widget _buildTaskItem(Task task) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        // Checkbox để đánh dấu hoàn thành
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (bool? value) {
            setState(() {
              task.isCompleted = value!;
            });
          },
          activeColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        // Tiêu đề công việc
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: task.isCompleted ? Colors.grey : Colors.black87,
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        // Thẻ phân loại công việc
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: task.categoryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            task.category,
            style: TextStyle(
              color: task.categoryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
