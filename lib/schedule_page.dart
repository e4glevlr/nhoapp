import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'models/schedule_item.dart';
import 'services/schedule_service.dart';
import 'services/auth_service.dart';
import '../widgets/schedule_item_dialog.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy user từ Provider
    final user = context.read<AuthService>().getCurrentUser();

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Vui lòng đăng nhập để xem lịch học."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thời Khóa Biểu Tuần'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ScheduleItemDialog(userId: user.uid),
              );
            },
          ),
        ],
      ),
      body: StreamProvider<List<ScheduleItem>>.value(
        value: ScheduleService().getScheduleStream(user.uid),
        initialData: const [],
        child: const TimetableGrid(),
      ),
    );
  }
}

class TimetableGrid extends StatefulWidget {
  const TimetableGrid({super.key});

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  final double hourHeight = 60.0;
  final double dayWidth = 150.0;
  final int startHour = 6;
  final int endHour = 22;

  // Tiện ích chuyển đổi "HH:mm" sang số giờ (vd: "07:30" -> 7.5)
  double _timeToHour(String time) {
    try {
      final parts = time.split(':');
      return double.parse(parts[0]) + double.parse(parts[1]) / 60.0;
    } catch (e) {
      return 7.0; // Mặc định
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleItems = Provider.of<List<ScheduleItem>>(context);
    final user = context.read<AuthService>().getCurrentUser()!;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Stack(
          children: [
            // Vẽ lưới nền và các ô trống
            _buildGridBackground(user.uid),
            // Vẽ các mục lịch học
            ...scheduleItems.map((item) => _buildScheduleItem(item, user.uid)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGridBackground(String userId) {
    final List<Widget> gridCells = [];
    final days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final dayMap = {2: 0, 3: 1, 4: 2, 5: 3, 6: 4, 7: 5, 1: 6}; // Map dayOfWeek to column index

    // Header ngày
    for (int i = 0; i < days.length; i++) {
      gridCells.add(
        Positioned(
          top: 0,
          left: 50.0 + (i * dayWidth),
          child: Container(
            width: dayWidth,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.grey[100],
            ),
            child: Center(child: Text(days[i], style: const TextStyle(fontWeight: FontWeight.bold))),
          ),
        ),
      );
    }

    // Cột giờ và các ô trống
    for (int hour = startHour; hour < endHour; hour++) {
      // Cột hiển thị giờ
      gridCells.add(
        Positioned(
          top: 40.0 + (hour - startHour) * hourHeight,
          left: 0,
          child: Container(
            width: 50,
            height: hourHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.grey[100],
            ),
            child: Center(child: Text('${hour}:00')),
          ),
        ),
      );

      // Các ô trống để nhấn vào
      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        final dayOfWeek = dayMap.entries.firstWhere((entry) => entry.value == dayIndex).key;
        gridCells.add(
          Positioned(
            top: 40.0 + (hour - startHour) * hourHeight,
            left: 50.0 + dayIndex * dayWidth,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => ScheduleItemDialog(
                    userId: userId,
                    initialDay: dayOfWeek,
                    initialTime: '${hour.toString().padLeft(2, '0')}:00',
                  ),
                );
              },
              child: Container(
                width: dayWidth,
                height: hourHeight,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                ),
              ),
            ),
          ),
        );
      }
    }

    return SizedBox(
      width: 50.0 + days.length * dayWidth,
      height: 40.0 + (endHour - startHour) * hourHeight,
      child: Stack(children: gridCells),
    );
  }

  Widget _buildScheduleItem(ScheduleItem item, String userId) {
    final dayMap = {2: 0, 3: 1, 4: 2, 5: 3, 6: 4, 7: 5, 1: 6};
    final dayIndex = dayMap[item.dayOfWeek] ?? 0;

    final top = 40.0 + (_timeToHour(item.startTime) - startHour) * hourHeight;
    final left = 50.0 + dayIndex * dayWidth;
    final height = (_timeToHour(item.endTime) - _timeToHour(item.startTime)) * hourHeight;

    if (height <= 0) return const SizedBox.shrink(); // Không vẽ nếu thời gian không hợp lệ

    return Positioned(
      top: top,
      left: left,
      width: dayWidth,
      height: height,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => ScheduleItemDialog(userId: userId, scheduleItem: item),
          );
        },
        child: Container(
          margin: const EdgeInsets.all(1.5),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${item.title}\n@ ${item.location}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: (height / 14).floor(), // Tính số dòng tối đa dựa trên chiều cao
          ),
        ),
      ),
    );
  }
}
