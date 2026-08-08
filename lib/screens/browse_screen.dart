import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/catalog.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/filter_bar.dart';
import '../widgets/async_view.dart';
import 'detail_screen.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});
  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  BrowseQuery _q = const BrowseQuery('all', '');
  String _keyword = '';
  final Set<String> _langs = {}; // rỗng = mọi loại; phude/thuyetminh/longtieng (chọn nhiều)
  final _scroll = ScrollController();

  // Lọc theo loại tiếng (phía app). Chọn nhiều -> khớp 1 trong các loại đã chọn.
  List<Movie> _applyLang(List<Movie> items) {
    if (_langs.isEmpty) return items;
    return items.where((m) =>
        (_langs.contains('phude') && m.hasPhuDe) ||
        (_langs.contains('thuyetminh') && m.hasThuyetMinh) ||
        (_langs.contains('longtieng') && m.hasLongTieng)).toList();
  }

  Widget _langChips() {
    Widget chip(String label, String? val) {
      final selected = val == null ? _langs.isEmpty : _langs.contains(val);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          selectedColor: kRed,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
          backgroundColor: kSurface,
          side: BorderSide.none,
          onSelected: (_) => setState(() {
            if (val == null) {
              _langs.clear();
            } else if (_langs.contains(val)) {
              _langs.remove(val);
            } else {
              _langs.add(val);
            }
          }),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(children: [
        chip('Mọi loại tiếng', null),
        chip('Phụ đề', 'phude'),
        chip('Thuyết minh', 'thuyetminh'),
        chip('Lồng tiếng', 'longtieng'),
      ]),
    );
  }

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(browseProvider(_q).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onKeyword(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _keyword = v);
    });
  }

  String _label(BrowseQuery q) {
    switch (q.kind) {
      case 'all': return 'Tất cả phim';
      case 'type': return kTypes.firstWhere((e) => e.slug == q.value, orElse: () => CatalogEntry(q.value, q.value)).label;
      case 'genre': return kGenres.firstWhere((e) => e.slug == q.value, orElse: () => CatalogEntry(q.value, q.value)).label;
      case 'country': return kCountries.firstWhere((e) => e.slug == q.value, orElse: () => CatalogEntry(q.value, q.value)).label;
      default: return 'Năm ${q.value}';
    }
  }

  Widget _grid(List<Movie> items) => GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: items.length,
        itemBuilder: (c, i) {
          final m = items[i];
          return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
        },
      );

  @override
  Widget build(BuildContext context) {
    final searching = _keyword.trim().length >= 2;
    return Column(children: [
      // Ô gõ tên phim
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Gõ tên phim để tìm...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _keyword.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54), onPressed: () => setState(() => _keyword = ''))
                : null,
            filled: true, fillColor: kSurface, isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onChanged: _onKeyword,
        ),
      ),
      if (!searching) FilterBar(current: _q, onChanged: (q) => setState(() => _q = q)),
      if (!searching)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(children: [
            Text(_label(_q), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ),
      _langChips(),
      Expanded(
        child: searching
            ? AsyncView(
                value: ref.watch(searchProvider(_keyword)),
                onRetry: () => ref.invalidate(searchProvider(_keyword)),
                builder: (list) {
                  final f = _applyLang(list);
                  return f.isEmpty
                      ? const Center(child: Text('Không tìm thấy phim', style: TextStyle(color: Colors.white38)))
                      : _grid(f);
                },
              )
            : _browseBody(),
      ),
    ]);
  }

  Widget _browseBody() {
    final st = ref.watch(browseProvider(_q));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (st.page < st.totalPage && !st.loading && _scroll.hasClients &&
          _scroll.position.maxScrollExtent < 400) {
        ref.read(browseProvider(_q).notifier).loadMore();
      }
    });
    return Column(children: [
      Expanded(child: _grid(_applyLang(st.items))),
      if (st.loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: kRed)),
    ]);
  }
}
