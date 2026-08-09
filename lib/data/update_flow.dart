import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'update_checker.dart';

/// Có thể tự tải + tự cài ngay không? (Android có APK, hoặc Windows có bộ cài .exe)
bool canAutoInstall(UpdateInfo info) =>
    (Platform.isAndroid && info.isApk) || (Platform.isWindows && info.isInstaller);

/// Tải + cài bản cập nhật (dùng chung cho banner trang chủ và nút trong Cài đặt).
/// Android: tải APK + hiện % + mở trình cài để cập nhật đè.
/// Windows: tải bộ cài .exe + hiện % + chạy im lặng (tự đóng app, cài đè, mở lại).
/// Không tự cài được -> mở link tải bằng trình duyệt.
Future<void> startUpdateFlow(BuildContext context, UpdateInfo info) async {
  void snack(String m) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  if (!canAutoInstall(info)) {
    UpdateChecker().openDownload(info.downloadUrl);
    return;
  }

  final progress = ValueNotifier<double>(0);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: kSurface,
      title: const Text('Đang tải bản cập nhật…', style: TextStyle(color: Colors.white)),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, p, __) => Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: p > 0 ? p : null, color: kRed, backgroundColor: Colors.white12),
          const SizedBox(height: 12),
          Text(p > 0 ? '${(p * 100).toStringAsFixed(0)}%' : 'Đang kết nối…',
              style: const TextStyle(color: Colors.white70)),
        ]),
      ),
    ),
  );

  if (Platform.isWindows) {
    final file = await UpdateChecker().downloadInstaller(info.downloadUrl, info.version, onProgress: (p) => progress.value = p);
    if (file == null) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
      snack('Tải bản cập nhật thất bại. Kiểm tra mạng rồi thử lại.');
      return;
    }
    progress.value = 1;
    final ok = await UpdateChecker().runWindowsInstaller(file);
    if (!ok) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
      snack('Không chạy được bộ cài. Thử lại hoặc tải thủ công.');
    }
    return;
  }

  // Android
  final file = await UpdateChecker().downloadApk(info.downloadUrl, onProgress: (p) => progress.value = p);
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  progress.dispose();

  if (file == null) {
    snack('Tải bản cập nhật thất bại. Kiểm tra mạng rồi thử lại.');
    return;
  }
  final ok = await UpdateChecker().installApk(file);
  if (!ok) {
    snack('Hãy cho phép VieFlix "Cài ứng dụng không rõ nguồn gốc", rồi bấm Cập nhật lại.');
  }
}
