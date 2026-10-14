import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/update_checker.dart';
import '../data/update_flow.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/top_nav.dart';
import 'home_screen.dart';
import 'watching_screen.dart';
import 'browse_screen.dart';
import 'my_list_screen.dart';
import 'settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _updateDismissed = false;

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), WatchingScreen(), BrowseScreen(), MyListScreen(), SettingsScreen()];
    final info = ref.watch(updateProvider).maybeWhen(data: (u) => u, orElse: () => null);
    final i = ref.watch(navTabProvider);
    void go(int v) => ref.read(navTabProvider.notifier).state = v;
    return PopScope(
      // Ở Trang chủ: nút Back thoát app. Ở tab khác: Back quay về Trang chủ trước.
      canPop: i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Đang gõ tìm phim -> Back chỉ THOÁT ô gõ, không nhảy về Trang chủ.
        if (ref.read(searchTypingProvider)) {
          ref.read(searchTypingProvider.notifier).state = false;
          return;
        }
        if (i != 0) go(0);
      },
      child: Scaffold(
        body: Stack(children: [
          // Ảnh nền điện ảnh phủ mờ: chỉ để tạo không khí, lớp tối dày phía trên
          // giữ chữ/thẻ phim đọc rõ. cacheWidth giới hạn bộ nhớ trên TV box yếu.
          Positioned.fill(
            child: Image.asset('assets/images/app_bg.jpg',
                fit: BoxFit.cover, cacheWidth: 1280, color: kBg.withValues(alpha: 0.72), colorBlendMode: BlendMode.srcOver),
          ),
          Column(children: [
            TopNav(
              selected: i,
              onSelect: go,
              // Bật cờ "đang gõ": màn Thư viện thấy cờ thì đưa con trỏ vào ô tìm
              // (cùng đường với nút Tìm trên TV -> TV hiện luôn bàn phím ảo).
              onSearch: () {
                go(kLibraryTab);
                ref.read(searchTypingProvider.notifier).state = true;
              },
            ),
            if (info != null && !_updateDismissed) _updateBanner(info),
            Expanded(child: pages[i]),
          ]),
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
            onPressed: () => startUpdateFlow(context, info),
            style: TextButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kRed),
            child: Text(canAutoInstall(info) ? 'Cập nhật ngay' : 'Tải về'),
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

}
