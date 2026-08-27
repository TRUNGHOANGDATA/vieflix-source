import 'package:flutter/foundation.dart';

/// Nhật ký chẩn đoán, in ra logcat trên Android (`adb logcat` tag `flutter`).
///
/// Có tiền tố cố định để lọc nhanh: `.	ool	v.ps1 log` rồi tìm `VIEFLIX`.
/// Dùng ở những nhánh mà trước đây app NUỐT LỖI im lặng — chính vì nuốt lỗi mà
/// lỗi trên TV không có cách nào lần ra được.
void vlog(String where, String msg) {
  debugPrint('VIEFLIX[$where] $msg');
}
