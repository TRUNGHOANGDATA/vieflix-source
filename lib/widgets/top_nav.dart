import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

const kNavItems = [
  NavItem(Icons.home, 'Trang chủ'),
  NavItem(Icons.grid_view, 'Thư viện phim'),
  NavItem(Icons.search, 'Tìm kiếm'),
  NavItem(Icons.favorite, 'Yêu thích'),
  NavItem(Icons.settings, 'Cài đặt'),
];

/// Thanh điều hướng ngang trên đỉnh (logo + các mục).
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
        const Text('PHIM MỚI', style: TextStyle(color: kRed, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 1)),
        const SizedBox(width: 32),
        for (int i = 0; i < kNavItems.length; i++) _item(i),
      ]),
    );
  }

  Widget _item(int i) {
    final sel = selected == i;
    return InkWell(
      onTap: () => onSelect(i),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Icon(kNavItems[i].icon, size: 18, color: sel ? kRed : Colors.white70),
          const SizedBox(width: 6),
          Text(kNavItems[i].label,
              style: TextStyle(color: sel ? kRed : Colors.white70, fontSize: 15, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}
