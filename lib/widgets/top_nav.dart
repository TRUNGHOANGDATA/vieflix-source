import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/update_checker.dart' show kAppVersion;
import 'tv_focusable.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

const kNavItems = [
  NavItem(Icons.home, 'Trang chủ'),
  NavItem(Icons.play_circle_outline, 'Đang xem'),
  NavItem(Icons.grid_view, 'Thư viện phim'),
  NavItem(Icons.search, 'Tìm kiếm'),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        FocusHighlight(
          onPressed: () => onSelect(0),
          scale: 1.0,
          builder: (f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: f ? kRed : Colors.transparent, width: 2),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(7, 6, 9, 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kRed, Color(0xFFB00610)]),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [BoxShadow(color: kRed.withValues(alpha: 0.55), blurRadius: 12)],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 9),
              const Text('Vie',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 23, letterSpacing: 0.3)),
              const Text('Flix',
                  style: TextStyle(color: kRed, fontWeight: FontWeight.w800, fontSize: 23, letterSpacing: 0.3)),
            ]),
          ),
        ),
        const SizedBox(width: 28),
        for (int i = 0; i < kNavItems.length; i++) _item(i),
        const Spacer(),
        // Phiên bản hiện tại — để mở app là biết đang chạy bản nào.
        Text('v$kAppVersion',
            style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _item(int i) {
    final sel = selected == i;
    return FocusHighlight(
      onPressed: () => onSelect(i),
      scale: 1.0,
      autofocus: i == 0, // để remote có điểm bắt đầu khi mở app
      builder: (f) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: f ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: f ? kRed : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          Icon(kNavItems[i].icon, size: 18, color: sel ? kRed : (f ? Colors.white : Colors.white70)),
          const SizedBox(width: 6),
          Text(kNavItems[i].label,
              style: TextStyle(
                  color: sel ? kRed : (f ? Colors.white : Colors.white70),
                  fontSize: 15,
                  fontWeight: (sel || f) ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}
