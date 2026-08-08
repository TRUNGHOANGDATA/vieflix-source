import 'package:flutter/material.dart';
import '../constants/catalog.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Thanh lọc một-chiều (API nguonc chỉ lọc một chiều). Mỗi ô có mục "Tất cả".
/// Chọn giá trị ở một ô sẽ đặt bộ lọc theo ô đó; các ô còn lại hiển thị "Tất cả".
class FilterBar extends StatelessWidget {
  final BrowseQuery current;
  final ValueChanged<BrowseQuery> onChanged;
  const FilterBar({super.key, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        _dd('Loại', 'type', {for (final t in kTypes) t.slug: t.label}),
        _dd('Thể loại', 'genre', {for (final g in kGenres) g.slug: g.label}),
        _dd('Quốc gia', 'country', {for (final c in kCountries) c.slug: c.label}),
        _dd('Năm', 'year', {for (final y in kYears) y: y}),
      ]),
    );
  }

  Widget _dd(String label, String kind, Map<String, String> options) {
    final active = current.kind == kind;
    final value = active ? current.value : '';
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? kRed : kSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: kSurface,
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: [
              DropdownMenuItem(value: '', child: Text('Tất cả $label')),
              ...options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v.isEmpty) {
                onChanged(const BrowseQuery('all', ''));
              } else {
                onChanged(BrowseQuery(kind, v));
              }
            },
          ),
        ),
      ),
    );
  }
}
