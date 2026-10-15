import 'package:flutter/material.dart';
import '../constants/catalog.dart';
import '../data/movie_source.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// Thanh lọc GHÉP: 4 nút Loại / Thể loại / Quốc gia / Năm, mỗi nút GIỮ lựa chọn
/// RIÊNG. Chọn nút này KHÔNG xoá nút kia — khác `TvFilterBar` (một chiều).
///
/// Bấm nút -> DANH SÁCH THẢ XUỐNG ngay dưới nút (như combo box), chọn một mục là
/// đóng. Trước 10/2026 là hộp thoại trải các viên thuốc ngang cả màn hình — chủ
/// dự án chê xấu, chậm chọn.
///
/// Dùng cho màn Thư viện, nơi lọc ghép nhiều chiều (phimapi kham được cả 4;
/// nguonc kham một chiều cấu trúc + năm — phần đó do lớp nguồn tự xử).
class MultiFilterBar extends StatelessWidget {
  final BrowseFilter current;
  final ValueChanged<BrowseFilter> onChanged;
  final EdgeInsets padding;

  const MultiFilterBar({
    super.key,
    required this.current,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = !current.isEmpty;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(children: [
        _FilterMenu(
          label: 'Loại', value: current.type,
          options: {for (final t in kTypes) t.slug: t.label},
          onPick: (v) => onChanged(current.copyWith(type: v, clearType: v == null)),
        ),
        _FilterMenu(
          label: 'Thể loại', value: current.genre,
          options: {for (final g in kGenres) g.slug: g.label},
          onPick: (v) => onChanged(current.copyWith(genre: v, clearGenre: v == null)),
        ),
        _FilterMenu(
          label: 'Quốc gia', value: current.country,
          options: {for (final c in kCountries) c.slug: c.label},
          onPick: (v) => onChanged(current.copyWith(country: v, clearCountry: v == null)),
        ),
        _FilterMenu(
          label: 'Năm', value: current.year,
          options: {for (final y in kYears) y: y},
          onPick: (v) => onChanged(current.copyWith(year: v, clearYear: v == null)),
        ),
        if (hasAny)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: FocusHighlight(
              scale: 1.0,
              onPressed: () => onChanged(const BrowseFilter()),
              builder: (f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: f ? kRed : Colors.white24, width: f ? 2 : 1.5),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.close, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text('Xoá lọc', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Một nút lọc + danh sách thả xuống của nó.
class _FilterMenu extends StatefulWidget {
  final String label;
  final String? value; // null = Tất cả
  final Map<String, String> options;
  final ValueChanged<String?> onPick;
  const _FilterMenu({required this.label, required this.value, required this.options, required this.onPick});
  @override
  State<_FilterMenu> createState() => _FilterMenuState();
}

class _FilterMenuState extends State<_FilterMenu> {
  final _ctl = MenuController();
  // Mục đang chọn (hoặc "Tất cả") — mở danh sách là con trỏ remote đậu ngay đó.
  final _focusTarget = FocusNode(debugLabel: 'filter-current');

  @override
  void dispose() {
    _focusTarget.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    if (_ctl.isOpen) {
      _ctl.close();
      return;
    }
    _ctl.open();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ctl.isOpen) _focusTarget.requestFocus();
    });
  }

  static final _itemStyle = ButtonStyle(
    foregroundColor: const WidgetStatePropertyAll(Colors.white),
    iconColor: const WidgetStatePropertyAll(Colors.white70),
    // Mục đang được remote chọn phải nổi rõ trên TV.
    backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused) ? kRed.withValues(alpha: 0.35) : null),
    overlayColor: WidgetStatePropertyAll(kRed.withValues(alpha: 0.18)),
    minimumSize: const WidgetStatePropertyAll(Size(220, 44)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
    textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontFamily: kBrandFont)),
  );

  Widget _item(String text, String? value) {
    final selected = widget.value == value;
    return MenuItemButton(
      focusNode: selected ? _focusTarget : null,
      style: _itemStyle,
      onPressed: () => widget.onPick(value),
      trailingIcon: selected ? const Icon(Icons.check, color: kRed, size: 18) : null,
      child: Text(text, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.value != null;
    final text = active ? (widget.options[widget.value] ?? widget.value!) : widget.label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: MenuAnchor(
        controller: _ctl,
        alignmentOffset: const Offset(0, 6),
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Color(0xFF1C1B27)),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          maximumSize: const WidgetStatePropertyAll(Size(300, 420)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white12),
          )),
        ),
        menuChildren: [
          _item('Tất cả ${widget.label.toLowerCase()}', null),
          for (final e in widget.options.entries) _item(e.value, e.key),
        ],
        builder: (context, ctl, _) => FocusHighlight(
          scale: 1.0,
          onPressed: _toggleOpen,
          builder: (f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active ? kRed : kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: f ? kRed : Colors.white12, width: f ? 2 : 1.5),
              boxShadow: f ? [BoxShadow(color: kRed.withValues(alpha: 0.45), blurRadius: 14)] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(text,
                  style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: (active || f) ? FontWeight.bold : FontWeight.w500)),
              const SizedBox(width: 6),
              Icon(ctl.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.white70, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}
