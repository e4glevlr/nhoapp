// lib/schedule_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_neat_and_clean_calendar/flutter_neat_and_clean_calendar.dart';

import 'models/schedule_item.dart';
import 'services/schedule_service.dart';
import 'services/auth_service.dart';
import 'widgets/schedule_item_dialog.dart';
import 'widgets/glassmorphic_container.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({Key? key}) : super(key: key);

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _color1;
  late Animation<Color?> _color2;

  List<NeatCleanCalendarEvent> _mappedEvents = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _color1 = ColorTween(
      begin: const Color(0xFF1E3A8A), // Blue Dark
      end: const Color(0xFF9333EA),   // Purple
    ).animate(_animationController);

    _color2 = ColorTween(
      begin: const Color(0xFF3B82F6), // Blue Light
      end: const Color(0xFFF472B6),   // Pink
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Ánh xạ danh sách các ScheduleItem từ Firestore thành các sự kiện
  /// mà thư viện lịch có thể hiển thị.
  /// Hỗ trợ cả sự kiện lặp lại trong khoảng thời gian và sự kiện một lần.
  List<NeatCleanCalendarEvent> _mapScheduleItemsToCalendarEvents(List<ScheduleItem> items) {
    final List<NeatCleanCalendarEvent> newEvents = [];

    for (final item in items) {
      if (item.isRecurring) {
        // Xử lý sự kiện lặp lại có giới hạn thời gian
        if (item.startDate != null && item.endDate != null && item.dayOfWeek != null) {
          // Lặp qua từng ngày trong khoảng thời gian đã cho
          for (var day = item.startDate!; day.isBefore(item.endDate!.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {

            // Chuyển đổi weekday của DateTime (1=T2, 7=CN) sang
            // quy ước của chúng ta (2=T2, 1=CN)
            int currentDayOfWeek = (day.weekday == 7) ? 1 : day.weekday + 1;

            if (currentDayOfWeek == item.dayOfWeek) {
              // Nếu đúng thứ trong tuần, tạo sự kiện
              try {
                final startTimeParts = item.startTime.split(':');
                final endTimeParts = item.endTime.split(':');
                final startTime = DateTime(day.year, day.month, day.day, int.parse(startTimeParts[0]), int.parse(startTimeParts[1]));
                final endTime = DateTime(day.year, day.month, day.day, int.parse(endTimeParts[0]), int.parse(endTimeParts[1]));

                newEvents.add(NeatCleanCalendarEvent(
                  item.title,
                  description: item.location,
                  startTime: startTime,
                  endTime: endTime,
                  color: item.color,
                  metadata: {'original_item': item},
                ));
              } catch (e) { /* Bỏ qua nếu có lỗi parse giờ */ }
            }
          }
        }
      } else {
        // Xử lý sự kiện chỉ diễn ra một lần
        if (item.specificDate != null) {
          try {
            final startTimeParts = item.startTime.split(':');
            final endTimeParts = item.endTime.split(':');
            final day = item.specificDate!;
            final startTime = DateTime(day.year, day.month, day.day, int.parse(startTimeParts[0]), int.parse(startTimeParts[1]));
            final endTime = DateTime(day.year, day.month, day.day, int.parse(endTimeParts[0]), int.parse(endTimeParts[1]));

            newEvents.add(NeatCleanCalendarEvent(
              item.title,
              description: item.location,
              startTime: startTime,
              endTime: endTime,
              color: item.color,
              isAllDay: false,
              metadata: {'original_item': item},
            ));
          } catch (e) { /* Bỏ qua nếu có lỗi parse giờ */ }
        }
      }
    }
    return newEvents;
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.getCurrentUser();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_color1.value!, _color2.value!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: user == null
                  ? _buildLoginPrompt()
                  : StreamProvider<List<ScheduleItem>>.value(
                value: ScheduleService().getScheduleStream(user.uid),
                initialData: const [],
                child: Consumer<List<ScheduleItem>>(
                  builder: (context, scheduleItems, child) {
                    _mappedEvents = _mapScheduleItemsToCalendarEvents(scheduleItems);
                    return Column(
                      children: [
                        _buildCustomAppBar(context, user.uid),
                        Expanded(
                          child: _buildCalendar(context, user.uid),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(24),
        borderRadius: 24.0,
        child: const Text(
          "Vui lòng đăng nhập để xem lịch học.",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, String userId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: SizedBox(
        height: kToolbarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Quay lại',
              ),
            ),
            const Text(
              'Thời Khóa Biểu',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 5.0, color: Colors.black26)]),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 30),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ScheduleItemDialog(
                      userId: userId,
                      initialDate: _selectedDate, // Truyền ngày đang được chọn vào dialog
                    ),
                  );
                },
                tooltip: 'Thêm Lịch học',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, String userId) {
    return Calendar(
      startOnMonday: true,
      weekDays: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
      eventsList: _mappedEvents,
      isExpandable: true,
      locale: 'vi_VN',
      isExpanded: true,
      onPrintLog: (log) {}, // Tắt log để giữ console sạch sẽ
      dayOfWeekStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
      bottomBarTextStyle: const TextStyle(color: Colors.white),
      bottomBarArrowColor: Colors.white,
      displayMonthTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      topRowIconColor: Colors.white,
      onDateSelected: (value) => setState(() => _selectedDate = value),
      onMonthChanged: (value) => setState(() => _selectedDate = value),
      onEventSelected: (value) {
        final originalItem = value.metadata?['original_item'] as ScheduleItem?;
        if (originalItem != null) {
          showDialog(
            context: context,
            builder: (_) => ScheduleItemDialog(userId: userId, scheduleItem: originalItem),
          );
        }
      },
      eventListBuilder: (context, events) {
        return _buildAnimatedEventList(context, events, userId);
      },
    );
  }

  Widget _buildAnimatedEventList(BuildContext context, List<NeatCleanCalendarEvent> events, String userId) {
    return Expanded(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: Container(
          key: ValueKey(_selectedDate.toIso8601String()),
          child: events.isEmpty
              ? const Center(
            child: Text('Không có sự kiện nào', style: TextStyle(color: Colors.white70)),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildEventListItem(context, event, userId);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEventListItem(BuildContext context, NeatCleanCalendarEvent event, String userId) {
    return GestureDetector(
      onTap: () {
        final originalItem = event.metadata?['original_item'] as ScheduleItem?;
        if (originalItem != null) {
          showDialog(
            context: context,
            builder: (_) => ScheduleItemDialog(userId: userId, scheduleItem: originalItem),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        child: GlassmorphicContainer(
          borderRadius: 12,
          opacity: 0.25,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 7,
                  decoration: BoxDecoration(
                    color: event.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.summary,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        if (event.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              event.description,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(DateFormat('HH:mm').format(event.startTime),
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(DateFormat('HH:mm').format(event.endTime),
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}