// lib/models/schedule_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScheduleItem {
  final String id;
  final String title;
  final String? subjectCode;
  final String location;
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final String? lecturer;
  final String? notes;
  final String colorHex;

  // --- CÁC TRƯỜNG ĐƯỢC THAY ĐỔI VÀ BỔ SUNG ---
  final bool isRecurring;
  // Chỉ dùng cho sự kiện lặp lại
  final int? dayOfWeek;
  final DateTime? startDate;
  final DateTime? endDate;
  // Chỉ dùng cho sự kiện một lần
  final DateTime? specificDate;

  ScheduleItem({
    required this.id,
    required this.title,
    this.subjectCode,
    required this.location,
    required this.startTime,
    required this.endTime,
    this.lecturer,
    this.notes,
    required this.colorHex,
    required this.isRecurring,
    this.dayOfWeek,
    this.startDate,
    this.endDate,
    this.specificDate,
  });

  // Chuyển đổi từ DocumentSnapshot của Firestore sang object ScheduleItem
  factory ScheduleItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ScheduleItem(
      id: doc.id,
      title: data['title'] ?? '',
      subjectCode: data['subjectCode'],
      location: data['location'] ?? '',
      startTime: data['startTime'] ?? '07:00',
      endTime: data['endTime'] ?? '09:00',
      lecturer: data['lecturer'],
      notes: data['notes'],
      colorHex: data['colorHex'] ?? '#FF5733',
      isRecurring: data['isRecurring'] ?? false, // Mặc định là sự kiện một lần
      dayOfWeek: data['dayOfWeek'],
      // Chuyển Timestamp từ Firestore về DateTime
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      specificDate: (data['specificDate'] as Timestamp?)?.toDate(),
    );
  }

  // Chuyển đổi từ object ScheduleItem sang Map để lưu vào Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subjectCode': subjectCode,
      'location': location,
      'startTime': startTime,
      'endTime': endTime,
      'lecturer': lecturer,
      'notes': notes,
      'colorHex': colorHex,
      'isRecurring': isRecurring,
      // Các trường có thể null
      'dayOfWeek': dayOfWeek,
      'startDate': startDate,
      'endDate': endDate,
      'specificDate': specificDate,
    };
  }

  Color get color => Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
}