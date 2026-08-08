import 'package:flutter/material.dart';
import '../constants/catalog.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Thanh lọc một-chiều: chọn giá trị ở bất kỳ nhóm nào sẽ đặt bộ lọc theo
/// nhóm đó (API nguonc chỉ lọc một chiều). Có nút "Xóa lọc".
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
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ChoiceChip(
            label: const Text('Tất cả'),
            selected: current.kind == 'all',
            selectedColor: kRed,
            backgroundColor: kSurface,
            labelStyle: const TextStyle(color: Colors.white),
            onSelected: (_) => onChanged(const BrowseQuery('all', '')),
          ),
        ),
        _dd('Loại', 'type', {for (final t in kTypes) t.slug: t.label}),
        _dd('Thể loại', 'genre', {for (final g in kGenres) g.slug: g.label}),
        _dd('Quốc gia', 'country', {for (final c in kCountries) c.slug: c.label}),
        _dd('Năm', 'year', {for (final y in kYears) y: y}),
      ]),
    );
  }

  Widget _dd(String label, String kind, Map<String, String> options) {
    final selected = current.kind == kind ? current.value : null;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected != null ? kRed : kSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected,
            hint: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            dropdownColor: kSurface,
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: options.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(BrowseQuery(kind, v));
            },
          ),
        ),
      ),
    );
  }
}
