import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/update_checker.dart' show kAppVersion;
import 'brand_logo.dart';
import 'tv_focusable.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

// "Thư viện phim" giờ gộp luôn Tìm kiếm (ô tìm + bộ lọc nằm trong đó) nên bỏ
// tab "Tìm kiếm" riêng. Cài đặt là mục cuối (index 4).
const kNavItems = [
  NavItem(Icons.home_rounded, 'Trang chủ'),
  NavItem(Icons.history, 'Đang xem'),
  NavItem(Icons.grid_view_rounded, 'Thư viện phim'),
  NavItem(Icons.favorite, 'Yêu thích'),
  NavItem(Icons.settings, 'Cài đặt'),
];

/// Index tab Thư viện phim — nơi có ô tìm kiếm thật.
const kLibraryTab = 2;

/// Thanh điều hướng ngang trên đỉnh (logo + các mục + ô tìm kiếm). Dùng tốt với
/// remote: mỗi mục sáng viền đỏ khi được chọn, bấm OK để mở. Mục đang mở: chữ đỏ
/// + gạch chân đỏ (theo mẫu thiết kế).
class TopNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const TopNav({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.82),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      // Lề rộng hơn để TV không cắt mất mép (overscan).
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: LayoutBuilder(builder: (context, cons) {
        // Màn hẹp (TV 960 điểm ảnh logic, iPad dọc): ô tìm thu về nút kính lúp
        // để hàng menu không tràn.
        final wideSearch = cons.maxWidth >= 1150;
        return Row(children: [
          FocusHighlight(
            onPressed: () => onSelect(0),
            scale: 1.0,
            builder: (f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: f ? kRed : Colors.transparent, width: 2),
              ),
              child: const BrandLogo(height: 30),
            ),
          ),
          const SizedBox(width: 18),
          for (int i = 0; i < kNavItems.length; i++) _item(i, compact: !wideSearch),
          const SizedBox(width: 12),
          // Phiên bản đặt LUÔN trong cụm trái để TV không cắt mất (trước đây dạt ra
          // mép phải nên bị overscan che).
          Text('v$kAppVersion',
              style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w600)),
          const Spacer(),
          _search(wideSearch),
        ]);
      }),
    );
  }

  /// Ô tìm kiếm: chỉ là lối tắt sang tab Thư viện phim (ô gõ thật nằm ở đó, có
  /// sẵn bộ lọc + tìm bằng giọng nói trên TV).
  Widget _search(bool wide) => FocusHighlight(
        onPressed: () => onSelect(kLibraryTab),
        scale: 1.0,
        builder: (f) => Container(
          width: wide ? 300 : null,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: f ? 0.14 : 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: f ? kRed : Colors.white12, width: f ? 2 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search, size: 19, color: Colors.white70),
            if (wide) ...[
              const SizedBox(width: 10),
              const Text('Tìm kiếm phim, diễn viên...',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ]),
        ),
      );

  Widget _item(int i, {bool compact = false}) {
    final sel = selected == i;
    return FocusHighlight(
      onPressed: () => onSelect(i),
      scale: 1.0,
      // Chỉ TV cần điểm bắt đầu cho remote. Trên PC/iPad mà tự chọn sẵn thì vừa
      // mở app đã thấy khung đỏ quanh "Trang chủ", nhìn như lỗi.
      autofocus: i == 0 && Platform.isAndroid,
      builder: (f) {
        final color = sel ? kRed : (f ? Colors.white : Colors.white70);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.fromLTRB(compact ? 8 : 11, 8, compact ? 8 : 11, 0),
          decoration: BoxDecoration(
            color: f ? Colors.white12 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: f ? kRed : Colors.transparent, width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(kNavItems[i].icon, size: 18, color: color),
              SizedBox(width: compact ? 5 : 7),
              Text(kNavItems[i].label,
                  style: TextStyle(
                      color: color,
                      fontSize: compact ? 13.5 : 14,
                      fontWeight: (sel || f) ? FontWeight.bold : FontWeight.w500)),
            ]),
            const SizedBox(height: 6),
            // Gạch chân đỏ dưới mục đang mở.
            Container(
              height: 3,
              width: 36,
              decoration: BoxDecoration(
                color: sel ? kRed : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: sel ? [BoxShadow(color: kRed.withValues(alpha: 0.7), blurRadius: 8)] : null,
              ),
            ),
          ]),
        );
      },
    );
  }
}
