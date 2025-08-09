import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScheduleItem {
  final String id;
  final String title;
  final String? subjectCode;
  final String location;
  final int dayOfWeek;
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final String? lecturer;
  final String? notes;
  final String colorHex;
  final bool isRecurring;

  ScheduleItem({
    required this.id,
    required this.title,
    this.subjectCode,
    required this.location,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.lecturer,
    this.notes,
    required this.colorHex,
    this.isRecurring = true,
  });

  // Chuyển đổi từ DocumentSnapshot của Firestore sang object ScheduleItem
  factory ScheduleItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ScheduleItem(
      id: doc.id,
      title: data['title'] ?? '',
      subjectCode: data['subjectCode'],
      location: data['location'] ?? '',
      dayOfWeek: data['dayOfWeek'] ?? 2,
      startTime: data['startTime'] ?? '07:00',
      endTime: data['endTime'] ?? '09:00',
      lecturer: data['lecturer'],
      notes: data['notes'],
      colorHex: data['colorHex'] ?? '#FF5733',
      isRecurring: data['isRecurring'] ?? true,
    );
  }

  // Chuyển đổi từ object ScheduleItem sang Map để lưu vào Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subjectCode': subjectCode,
      'location': location,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'lecturer': lecturer,
      'notes': notes,
      'colorHex': colorHex,
      'isRecurring': isRecurring,
    };
  }

  // Tiện ích để lấy màu từ mã hex
  Color get color => Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
}
