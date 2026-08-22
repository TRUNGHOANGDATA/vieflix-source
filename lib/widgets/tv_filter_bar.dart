import 'package:flutter/material.dart';
import '../constants/catalog.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// Thanh lọc kiểu TV: 4 NÚT (Loại / Thể loại / Quốc gia / Năm). Bấm 1 nút mở
/// bảng chọn full màn, D-pad chọn dễ — thay cho `DropdownButton` cũ (remote
/// gần như không bấm vào được, gây "kẹt hàng trên").
///
/// Nguồn nguonc chỉ lọc MỘT chiều: chọn giá trị ở một nhóm sẽ đặt bộ lọc theo
/// nhóm đó; các nhóm còn lại hiển thị "Tất cả".
class TvFilterBar extends StatelessWidget {
  final BrowseQuery current;
  final ValueChanged<BrowseQuery> onChanged;

  /// Le ngoai. Man Thu vien nhung thanh nay vao chung mot hang voi o tim nen
  /// truyen EdgeInsets.zero; man "Xem tat ca" giu nguyen le cu.
  final EdgeInsets padding;

  const TvFilterBar({
    super.key,
    required this.current,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(children: [
        _btn(context, 'Loại', 'type', {for (final t in kTypes) t.slug: t.label}),
        _btn(context, 'Thể loại', 'genre', {for (final g in kGenres) g.slug: g.label}),
        _btn(context, 'Quốc gia', 'country', {for (final c in kCountries) c.slug: c.label}),
        _btn(context, 'Năm', 'year', {for (final y in kYears) y: y}),
      ]),
    );
  }

  Widget _btn(BuildContext context, String label, String kind, Map<String, String> options) {
    final active = current.kind == kind;
    final valueLabel = active ? (options[current.value] ?? current.value) : 'Tất cả $label';
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: FocusHighlight(
        scale: 1.0,
        onPressed: () async {
          final picked = await _openPicker(context, label, kind, options);
          if (picked == null) return; // huỷ, không đổi gì
          if (picked.isEmpty) {
            onChanged(const BrowseQuery('all', ''));
          } else {
            onChanged(BrowseQuery(kind, picked));
          }
        },
        builder: (f) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? kRed : kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: f ? kRed : Colors.white12, width: f ? 2 : 1.5),
            boxShadow: f ? [BoxShadow(color: kRed.withValues(alpha: 0.45), blurRadius: 14)] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(valueLabel,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: (active || f) ? FontWeight.bold : FontWeight.w500)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
          ]),
        ),
      ),
    );
  }

  /// Bảng chọn: danh sách "viên thuốc" bấm bằng D-pad. Con trỏ vào bảng đậu sẵn
  /// ở mục đang chọn (autofocus). Trả về slug đã chọn; '' = "Tất cả"; null = huỷ.
  Future<String?> _openPicker(
      BuildContext context, String label, String kind, Map<String, String> options) {
    final activeValue = current.kind == kind ? current.value : '';
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF15171F),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chọn $label',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(spacing: 10, runSpacing: 10, children: [
                    _opt(ctx, 'Tất cả $label', '', activeValue.isEmpty),
                    for (final e in options.entries)
                      _opt(ctx, e.value, e.key, activeValue == e.key),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opt(BuildContext ctx, String text, String value, bool selected) {
    return FocusHighlight(
      autofocus: selected, // con trỏ đậu sẵn ở mục đang chọn
      scale: 1.0,
      onPressed: () => Navigator.pop(ctx, value),
      builder: (f) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? kRed : (f ? kRed.withValues(alpha: 0.25) : kSurface),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: (f || selected) ? kRed : Colors.white12, width: f ? 2 : 1.5),
          boxShadow: f ? [BoxShadow(color: kRed.withValues(alpha: 0.45), blurRadius: 14)] : null,
        ),
        child: Text(text,
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: (selected || f) ? FontWeight.bold : FontWeight.w500)),
      ),
    );
  }
}
