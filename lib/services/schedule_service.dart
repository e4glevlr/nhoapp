import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_item.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _getScheduleCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('schedule_items');
  }

  Stream<List<ScheduleItem>> getScheduleStream(String userId) {
    return _getScheduleCollection(userId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ScheduleItem.fromFirestore(doc)).toList();
    });
  }

  Future<void> addScheduleItem(String userId, ScheduleItem item) async {
    try {
      await _getScheduleCollection(userId).add(item.toMap());
    } catch (e) {
      print('Lỗi khi thêm lịch học: $e');
      rethrow;
    }
  }

  Future<void> updateScheduleItem(String userId, ScheduleItem item) async {
    try {
      await _getScheduleCollection(userId).doc(item.id).update(item.toMap());
    } catch (e) {
      print('Lỗi khi cập nhật lịch học: $e');
      rethrow;
    }
  }

  Future<void> deleteScheduleItem(String userId, String itemId) async {
    try {
      await _getScheduleCollection(userId).doc(itemId).delete();
    } catch (e) {
      print('Lỗi khi xóa lịch học: $e');
      rethrow;
    }
  }

}
