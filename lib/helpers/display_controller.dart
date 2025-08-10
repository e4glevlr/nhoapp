// lib/helpers/display_controller.dart

import 'package:flutter/material.dart';

/// Controller để điều khiển việc hiển thị widget thật hoặc ảnh chụp.
class DisplayController extends ChangeNotifier {
  bool _isRealWidgetVisible = false;

  /// Kiểm tra xem widget thật có đang được hiển thị hay không.
  bool get isRealWidgetVisible => _isRealWidgetVisible;

  /// Yêu cầu hiển thị widget thật.
  void showRealWidget() {
    if (!_isRealWidgetVisible) {
      _isRealWidgetVisible = true;
      notifyListeners();
    }
  }

  /// Reset về trạng thái hiển thị ảnh chụp.
  void showSnapshot() {
    if (_isRealWidgetVisible) {
      _isRealWidgetVisible = false;
      // Không cần notifyListeners ở đây để tránh rebuild không cần thiết khi reset.
    }
  }
}