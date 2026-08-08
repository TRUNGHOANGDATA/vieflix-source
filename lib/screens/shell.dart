import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/update_checker.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/top_nav.dart';
import 'home_screen.dart';
import 'watching_screen.dart';
import 'browse_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _i = 0;
  bool _updateDismissed = false;

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), WatchingScreen(), BrowseScreen(), SearchScreen(), MyListScreen()];
    final info = ref.watch(updateProvider).maybeWhen(data: (u) => u, orElse: () => null);
    return PopScope(
      // Ở Trang chủ: nút Back thoát app. Ở tab khác: Back quay về Trang chủ trước.
      canPop: _i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _i != 0) setState(() => _i = 0);
      },
      child: Scaffold(
        body: Column(children: [
          TopNav(selected: _i, onSelect: (v) => setState(() => _i = v)),
          if (info != null && !_updateDismissed) _updateBanner(info),
          Expanded(child: pages[_i]),
        ]),
      ),
    );
  }

  Widget _updateBanner(UpdateInfo info) {
    return Material(
      color: kRed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.system_update, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đã có bản cập nhật mới v${info.version} — cập nhật để dùng bản mới nhất',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _startUpdate(info),
            style: TextButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kRed),
            child: Text(_canAutoInstall(info) ? 'Cập nhật ngay' : 'Tải về'),
          ),
          IconButton(
            onPressed: () => setState(() => _updateDismissed = true),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            tooltip: 'Bỏ qua',
          ),
        ]),
      ),
    );
  }

  /// Có thể tự tải + tự cài ngay không? (Android có APK, hoặc Windows có bộ cài .exe)
  bool _canAutoInstall(UpdateInfo info) =>
      (Platform.isAndroid && info.isApk) || (Platform.isWindows && info.isInstaller);

  /// Android: tải APK về + hiện % + mở trình cài đặt để cập nhật đè.
  /// Windows: tải bộ cài .exe + hiện % + chạy im lặng (tự đóng app, cài đè, mở lại).
  /// Không tự cài được -> mở link tải bằng trình duyệt.
  Future<void> _startUpdate(UpdateInfo info) async {
    if (!_canAutoInstall(info)) {
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
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        progress.dispose();
        _snack('Tải bản cập nhật thất bại. Kiểm tra mạng rồi thử lại.');
        return;
      }
      // Đổi thông báo sang "đang cài" trước khi app tự thoát.
      progress.value = 1;
      // runWindowsInstaller sẽ thoát app -> không cần đóng hộp thoại.
      final ok = await UpdateChecker().runWindowsInstaller(file);
      if (!ok) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        progress.dispose();
        _snack('Không chạy được bộ cài. Thử lại hoặc tải thủ công.');
      }
      return;
    }

    // Android
    final file = await UpdateChecker().downloadApk(info.downloadUrl, onProgress: (p) => progress.value = p);
    if (mounted) Navigator.of(context, rootNavigator: true).pop(); // đóng hộp tải
    progress.dispose();

    if (file == null) {
      _snack('Tải bản cập nhật thất bại. Kiểm tra mạng rồi thử lại.');
      return;
    }
    final ok = await UpdateChecker().installApk(file);
    if (!ok) {
      _snack('Hãy cho phép VieFlix "Cài ứng dụng không rõ nguồn gốc", rồi bấm Cập nhật lại.');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}
