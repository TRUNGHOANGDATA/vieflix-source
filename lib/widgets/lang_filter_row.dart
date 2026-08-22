import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// Hàng lọc theo LOẠI TIẾNG (Phụ đề / Thuyết minh / Lồng tiếng), chọn nhiều.
/// Chip kiểu TV: sáng đỏ khi chọn + quầng đỏ khi remote trỏ tới. Dùng chung cho
/// màn Thư viện và trang "Xem tất cả" để đồng nhất.
class LangFilterRow extends StatelessWidget {
  final Set<String> selected; // chứa: phude / thuyetminh / longtieng
  final ValueChanged<Set<String>> onChanged;

  /// Lề ngoài — màn Thư viện cần bó sát để khối lọc không ăn hết chiều cao.
  final EdgeInsets padding;

  const LangFilterRow({
    super.key,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 2, 16, 6),
  });

  void _toggle(String? val) {
    final next = Set<String>.from(selected);
    if (val == null) {
      next.clear(); // "Mọi loại tiếng" -> bỏ hết lựa chọn
    } else if (next.contains(val)) {
      next.remove(val);
    } else {
      next.add(val);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(children: [
          _chip('Mọi loại tiếng', null),
          _chip('Phụ đề', 'phude'),
          _chip('Thuyết minh', 'thuyetminh'),
          _chip('Lồng tiếng', 'longtieng'),
        ]),
      );

  Widget _chip(String label, String? val) {
    final sel = val == null ? selected.isEmpty : selected.contains(val);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FocusHighlight(
        scale: 1.0,
        onPressed: () => _toggle(val),
        builder: (f) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? kRed : kSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: (f || sel) ? kRed : Colors.white12, width: f ? 2 : 1.5),
            boxShadow: f ? [BoxShadow(color: kRed.withValues(alpha: 0.45), blurRadius: 12)] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (sel)
              const Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              ),
            Text(label,
                style: TextStyle(
                    color: sel ? Colors.white : Colors.white70,
                    fontSize: 13.5,
                    fontWeight: (sel || f) ? FontWeight.bold : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
