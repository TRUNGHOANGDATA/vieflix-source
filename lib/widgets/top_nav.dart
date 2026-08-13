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
// tab "Tìm kiếm" riêng.
const kNavItems = [
  NavItem(Icons.home, 'Trang chủ'),
  NavItem(Icons.play_circle_outline, 'Đang xem'),
  NavItem(Icons.grid_view, 'Thư viện phim'),
  NavItem(Icons.favorite, 'Yêu thích'),
];

/// Thanh điều hướng ngang trên đỉnh (logo + các mục). Dùng tốt với remote:
/// mỗi mục sáng lên khi được chọn, bấm OK để mở.
class TopNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const TopNav({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      // Lề rộng hơn để TV không cắt mất mép (overscan).
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Row(children: [
        FocusHighlight(
          onPressed: () => onSelect(0),
          scale: 1.0,
          builder: (f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: f ? kRed : Colors.transparent, width: 2),
            ),
            child: const BrandLogo(height: 28),
          ),
        ),
        const SizedBox(width: 14),
        for (int i = 0; i < kNavItems.length; i++) _item(i),
        // Nút Cài đặt (bánh răng) đặt ngay sau các tab cho gọn, không dạt hẳn ra mép phải.
        _settings(),
        const SizedBox(width: 12),
        // Phiên bản đặt LUÔN trong cụm trái để TV không cắt mất (trước đây dạt ra
        // mép phải nên bị overscan che). Spacer đẩy phần còn lại về phải.
        Text('v$kAppVersion',
            style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
        const Spacer(),
      ]),
    );
  }

  /// Nút Cài đặt ở góc phải (index = kNavItems.length).
  Widget _settings() {
    const idx = 4; // ngay sau 4 tab thường
    final sel = selected == idx;
    return FocusHighlight(
      onPressed: () => onSelect(idx),
      scale: 1.0,
      builder: (f) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: f ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: f ? kRed : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          Icon(Icons.settings, size: 16, color: sel ? kRed : (f ? Colors.white : Colors.white70)),
          const SizedBox(width: 5),
          Text('Cài đặt',
              style: TextStyle(
                  color: sel ? kRed : (f ? Colors.white : Colors.white70),
                  fontSize: 13.5,
                  fontWeight: (sel || f) ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _item(int i) {
    final sel = selected == i;
    return FocusHighlight(
      onPressed: () => onSelect(i),
      scale: 1.0,
      autofocus: i == 0, // để remote có điểm bắt đầu khi mở app
      builder: (f) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: f ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: f ? kRed : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          Icon(kNavItems[i].icon, size: 16, color: sel ? kRed : (f ? Colors.white : Colors.white70)),
          const SizedBox(width: 5),
          Text(kNavItems[i].label,
              style: TextStyle(
                  color: sel ? kRed : (f ? Colors.white : Colors.white70),
                  fontSize: 13.5,
                  fontWeight: (sel || f) ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}
