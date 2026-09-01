import 'package:flutter/material.dart';
import '../constants/catalog.dart';
import '../data/movie_source.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// Thanh lọc GHÉP: 4 nút Loại / Thể loại / Quốc gia / Năm, mỗi nút GIỮ lựa chọn
/// RIÊNG. Chọn nút này KHÔNG xoá nút kia — khác `TvFilterBar` (một chiều).
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
        _btn(context, 'Loại', current.type, {for (final t in kTypes) t.slug: t.label},
            (v) => onChanged(current.copyWith(type: v, clearType: v == null))),
        _btn(context, 'Thể loại', current.genre, {for (final g in kGenres) g.slug: g.label},
            (v) => onChanged(current.copyWith(genre: v, clearGenre: v == null))),
        _btn(context, 'Quốc gia', current.country, {for (final c in kCountries) c.slug: c.label},
            (v) => onChanged(current.copyWith(country: v, clearCountry: v == null))),
        _btn(context, 'Năm', current.year, {for (final y in kYears) y: y},
            (v) => onChanged(current.copyWith(year: v, clearYear: v == null))),
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

  Widget _btn(BuildContext context, String label, String? value,
      Map<String, String> options, ValueChanged<String?> onPick) {
    final active = value != null;
    final valueLabel = active ? (options[value] ?? value) : label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: FocusHighlight(
        scale: 1.0,
        onPressed: () async {
          final picked = await _openPicker(context, label, value, options);
          if (picked == null) return; // huỷ hộp thoại, không đổi gì
          onPick(picked.isEmpty ? null : picked); // '' = bỏ chọn chiều này
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
            Icon(active ? Icons.check : Icons.arrow_drop_down,
                color: Colors.white70, size: active ? 16 : 20),
          ]),
        ),
      ),
    );
  }

  Future<String?> _openPicker(BuildContext context, String label,
      String? activeValue, Map<String, String> options) {
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
                    _opt(ctx, 'Tất cả $label', '', activeValue == null),
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
      autofocus: selected,
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
