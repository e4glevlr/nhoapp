import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import '../models/schedule_item.dart';
import '../services/schedule_service.dart';

class ScheduleItemDialog extends StatefulWidget {
  final String userId;
  final ScheduleItem? scheduleItem; // null nếu là thêm mới
  final int? initialDay; // Ngày được chọn khi nhấn ô trống
  final String? initialTime; // Giờ được chọn khi nhấn ô trống

  const ScheduleItemDialog({
    super.key,
    required this.userId,
    this.scheduleItem,
    this.initialDay,
    this.initialTime,
  });

  @override
  _ScheduleItemDialogState createState() => _ScheduleItemDialogState();
}

class _ScheduleItemDialogState extends State<ScheduleItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _title, _location, _startTime, _endTime, _colorHex;
  String? _subjectCode, _lecturer, _notes;
  late int _dayOfWeek;
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
    _dayOfWeek = item?.dayOfWeek ?? widget.initialDay ?? 2;
    _startTime = item?.startTime ?? widget.initialTime ?? '07:00';
    // Mặc định endTime sau startTime 2 tiếng
    _endTime = item?.endTime ?? _calculateDefaultEndTime(_startTime);
    _colorHex = item?.colorHex ?? '#FF5733';
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn một màu'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: Color(int.parse(_colorHex.substring(1, 7), radix: 16) + 0xFF000000),
            onColorChanged: (color) {
              setState(() {
                _colorHex = '#${color.value.toRadixString(16).substring(2)}';
              });
            },
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('Chọn'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      final newItem = ScheduleItem(
        id: widget.scheduleItem?.id ?? '', // id sẽ được bỏ qua khi thêm mới
        title: _title,
        location: _location,
        dayOfWeek: _dayOfWeek,
        startTime: _startTime,
        endTime: _endTime,
        colorHex: _colorHex,
        subjectCode: _subjectCode,
        lecturer: _lecturer,
        notes: _notes,
      );

      try {
        if (widget.scheduleItem == null) {
          // Thêm mới
          await _scheduleService.addScheduleItem(widget.userId, newItem);
        } else {
          // Cập nhật
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

  Future<void> _deleteItem() async {
    if (widget.scheduleItem != null) {
      setState(() => _isSaving = true);
      try {
        await _scheduleService.deleteScheduleItem(widget.userId, widget.scheduleItem!.id);
        if (mounted) Navigator.of(context).pop(); // Đóng dialog hiện tại
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


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.scheduleItem == null ? 'Thêm Lịch Học' : 'Sửa Lịch Học'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Tên môn học/Sự kiện'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập tên' : null,
                onSaved: (value) => _title = value!,
              ),
              TextFormField(
                initialValue: _location,
                decoration: const InputDecoration(labelText: 'Địa điểm (Phòng học)'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập địa điểm' : null,
                onSaved: (value) => _location = value!,
              ),
              DropdownButtonFormField<int>(
                value: _dayOfWeek,
                decoration: const InputDecoration(labelText: 'Ngày trong tuần'),
                items: const [
                  DropdownMenuItem(value: 2, child: Text('Thứ Hai')),
                  DropdownMenuItem(value: 3, child: Text('Thứ Ba')),
                  DropdownMenuItem(value: 4, child: Text('Thứ Tư')),
                  DropdownMenuItem(value: 5, child: Text('Thứ Năm')),
                  DropdownMenuItem(value: 6, child: Text('Thứ Sáu')),
                  DropdownMenuItem(value: 7, child: Text('Thứ Bảy')),
                  DropdownMenuItem(value: 1, child: Text('Chủ Nhật')),
                ],
                onChanged: (value) => setState(() => _dayOfWeek = value!),
              ),
              Row(
                children: [
                  Expanded(child: Text('Bắt đầu: $_startTime')),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: () => _selectTime(context, true),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text('Kết thúc: $_endTime')),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: () => _selectTime(context, false),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Màu sắc: '),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showColorPicker,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(int.parse(_colorHex.substring(1, 7), radix: 16) + 0xFF000000),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _lecturer,
                decoration: const InputDecoration(labelText: 'Giảng viên (Tùy chọn)'),
                onSaved: (value) => _lecturer = value,
              ),
              TextFormField(
                initialValue: _notes,
                decoration: const InputDecoration(labelText: 'Ghi chú (Tùy chọn)'),
                onSaved: (value) => _notes = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.scheduleItem != null)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isSaving ? null : _deleteItem,
          ),
        const Spacer(),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveForm,
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu'),
        ),
      ],
    );
  }
}
