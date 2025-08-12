// lib/widgets/schedule_item_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import '../models/schedule_item.dart';
import '../services/schedule_service.dart';

class ScheduleItemDialog extends StatefulWidget {
  final String userId;
  final ScheduleItem? scheduleItem;
  final DateTime? initialDate;

  const ScheduleItemDialog({
    super.key,
    required this.userId,
    this.scheduleItem,
    this.initialDate,
  });

  @override
  _ScheduleItemDialogState createState() => _ScheduleItemDialogState();
}

class _ScheduleItemDialogState extends State<ScheduleItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _title, _location, _startTime, _endTime, _colorHex;
  String? _subjectCode, _lecturer, _notes;

  // Dùng ValueNotifier để quản lý trạng thái lặp lại, giúp chỉ build lại phần UI cần thiết
  late final ValueNotifier<bool> _isRecurringNotifier;

  int _dayOfWeek = 2; // Mặc định là Thứ Hai
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));
  DateTime _specificDate = DateTime.now();

  bool _isSaving = false;
  final ScheduleService _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    final item = widget.scheduleItem;

    _title = item?.title ?? '';
    _location = item?.location ?? '';
    _subjectCode = item?.subjectCode;
    _lecturer = item?.lecturer;
    _notes = item?.notes;
    _startTime = item?.startTime ?? '07:00';
    _endTime = item?.endTime ?? _calculateDefaultEndTime(_startTime);
    _colorHex = item?.colorHex ?? '#FF5733';

    final isRecurring = item?.isRecurring ?? false;
    _isRecurringNotifier = ValueNotifier<bool>(isRecurring);

    if (item != null) {
      if (isRecurring) {
        _dayOfWeek = item.dayOfWeek ?? 2;
        _startDate = item.startDate ?? DateTime.now();
        _endDate = item.endDate ?? DateTime.now().add(const Duration(days: 90));
      } else {
        _specificDate = item.specificDate ?? widget.initialDate ?? DateTime.now();
      }
    } else {
      _specificDate = widget.initialDate ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _isRecurringNotifier.dispose();
    super.dispose();
  }

  String _calculateDefaultEndTime(String startTime) {
    try {
      final format = DateFormat.Hm();
      final dt = format.parse(startTime);
      final newDt = dt.add(const Duration(hours: 2));
      return format.format(newDt);
    } catch (e) {
      return '09:00';
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final initialTime = TimeOfDay.fromDateTime(
      DateFormat.Hm().parse(isStartTime ? _startTime : _endTime),
    );
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        final formattedTime = pickedTime.format(context);
        if (isStartTime) {
          _startTime = formattedTime;
        } else {
          _endTime = formattedTime;
        }
      });
    }
  }

  void _showColorPicker() {
    Color pickerColor = Color(int.parse(_colorHex.substring(1, 7), radix: 16) + 0xFF000000);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn một màu'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('Chọn'),
            onPressed: () {
              setState(() {
                _colorHex = '#${pickerColor.value.toRadixString(16).substring(2)}';
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem() async {
    if (widget.scheduleItem == null) return;

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Bạn có chắc chắn muốn xóa lịch học này không?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() => _isSaving = true);
      try {
        await _scheduleService.deleteScheduleItem(widget.userId, widget.scheduleItem!.id);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xóa thất bại: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, {required Function(DateTime) onDateSelected, required DateTime initialDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      final bool isRecurring = _isRecurringNotifier.value;
      final newItem = ScheduleItem(
        id: widget.scheduleItem?.id ?? '',
        title: _title,
        location: _location,
        startTime: _startTime,
        endTime: _endTime,
        colorHex: _colorHex,
        subjectCode: _subjectCode,
        lecturer: _lecturer,
        notes: _notes,
        isRecurring: isRecurring,
        dayOfWeek: isRecurring ? _dayOfWeek : null,
        startDate: isRecurring ? _startDate : null,
        endDate: isRecurring ? _endDate : null,
        specificDate: !isRecurring ? _specificDate : null,
      );

      try {
        if (widget.scheduleItem == null) {
          await _scheduleService.addScheduleItem(widget.userId, newItem);
        } else {
          await _scheduleService.updateScheduleItem(widget.userId, newItem);
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lưu thất bại: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.white);
    const inputDecorationTheme = InputDecoration(
      labelStyle: TextStyle(color: Colors.white70),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      errorStyle: TextStyle(color: Color.fromARGB(255, 255, 129, 129)),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.scheduleItem == null ? 'Thêm Lịch' : 'Sửa Lịch', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: _title,
                        style: textStyle,
                        decoration: inputDecorationTheme.copyWith(labelText: 'Tên môn học/Sự kiện'),
                        validator: (value) => value!.isEmpty ? 'Vui lòng nhập tên' : null,
                        onSaved: (value) => _title = value!,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _location,
                        style: textStyle,
                        decoration: inputDecorationTheme.copyWith(labelText: 'Địa điểm (Phòng học)'),
                        validator: (value) => value!.isEmpty ? 'Vui lòng nhập địa điểm' : null,
                        onSaved: (value) => _location = value!,
                      ),
                      const SizedBox(height: 16),
                      _buildEventTypeSwitch(),
                      const SizedBox(height: 16),

                      ValueListenableBuilder<bool>(
                        valueListenable: _isRecurringNotifier,
                        builder: (context, isRecurring, child) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(sizeFactor: animation, child: child),
                              );
                            },
                            child: Column(
                              key: ValueKey(isRecurring),
                              children: isRecurring
                                  ? _buildRecurringFields(textStyle, inputDecorationTheme)
                                  : _buildOneTimeFields(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                      _buildTimeRow('Bắt đầu:', _startTime, () => _selectTime(context, true)),
                      _buildTimeRow('Kết thúc:', _endTime, () => _selectTime(context, false)),
                      const SizedBox(height: 12),
                      _buildColorPickerRow(),
                      const SizedBox(height: 10),

                      TextFormField(
                        initialValue: _lecturer,
                        style: textStyle,
                        decoration: inputDecorationTheme.copyWith(labelText: 'Giảng viên (Tùy chọn)'),
                        onSaved: (value) => _lecturer = value,
                      ),
                      TextFormField(
                        initialValue: _notes,
                        style: textStyle,
                        decoration: inputDecorationTheme.copyWith(labelText: 'Ghi chú (Tùy chọn)'),
                        onSaved: (value) => _notes = value,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildActionsRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventTypeSwitch() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isRecurringNotifier,
      builder: (context, isRecurring, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(child: _buildSwitchOption('Một lần', !isRecurring)),
              Expanded(child: _buildSwitchOption('Lặp lại', isRecurring)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwitchOption(String title, bool isSelected) {
    return GestureDetector(
      onTap: () {
        _isRecurringNotifier.value = (title == 'Lặp lại');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  List<Widget> _buildRecurringFields(TextStyle textStyle, InputDecoration decoration) {
    return [
      DropdownButtonFormField<int>(
        value: _dayOfWeek,
        decoration: decoration.copyWith(labelText: 'Ngày trong tuần'),
        dropdownColor: Colors.blueGrey[700],
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
        items: [
          DropdownMenuItem(value: 2, child: Text('Thứ Hai', style: textStyle)),
          DropdownMenuItem(value: 3, child: Text('Thứ Ba', style: textStyle)),
          DropdownMenuItem(value: 4, child: Text('Thứ Tư', style: textStyle)),
          DropdownMenuItem(value: 5, child: Text('Thứ Năm', style: textStyle)),
          DropdownMenuItem(value: 6, child: Text('Thứ Sáu', style: textStyle)),
          DropdownMenuItem(value: 7, child: Text('Thứ Bảy', style: textStyle)),
          DropdownMenuItem(value: 1, child: Text('Chủ Nhật', style: textStyle)),
        ],
        onChanged: (value) => setState(() => _dayOfWeek = value!),
      ),
      const SizedBox(height: 16),
      _buildDateRow("Từ ngày:", _startDate, (date) => setState(() => _startDate = date)),
      _buildDateRow("Đến ngày:", _endDate, (date) => setState(() => _endDate = date)),
    ];
  }

  List<Widget> _buildOneTimeFields() {
    return [_buildDateRow("Ngày diễn ra:", _specificDate, (date) => setState(() => _specificDate = date))];
  }

  Widget _buildDateRow(String label, DateTime date, Function(DateTime) onDateSelected) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          DateFormat('dd/MM/yyyy').format(date),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.edit_calendar_outlined, color: Colors.white70),
          onPressed: () => _selectDate(context, onDateSelected: onDateSelected, initialDate: date),
        ),
      ],
    );
  }

  Widget _buildTimeRow(String label, String time, VoidCallback onPressed) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(width: 8),
        Text(time, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.edit_calendar_outlined, color: Colors.white70),
          onPressed: onPressed,
        ),
      ],
    );
  }

  Widget _buildColorPickerRow() {
    return Row(
      children: [
        const Text('Màu sắc:', style: TextStyle(color: Colors.white70, fontSize: 16)),
        const Spacer(),
        GestureDetector(
          onTap: _showColorPicker,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(int.parse(_colorHex.substring(1, 7), radix: 16) + 0xFF000000),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        if (widget.scheduleItem != null)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _isSaving ? null : _deleteItem,
            tooltip: "Xóa",
          ),
        const Spacer(),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _saveForm,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}