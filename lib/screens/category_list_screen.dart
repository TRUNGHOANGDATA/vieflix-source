import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/tv_filter_bar.dart';
import '../widgets/lang_filter_row.dart';
import '../widgets/async_view.dart';
import '../widgets/shimmer.dart';
import 'detail_screen.dart';

/// Trang danh sách đầy đủ: có ô tìm tên + bộ lọc + cuộn vô tận.
class CategoryListScreen extends ConsumerStatefulWidget {
  final String title;
  final BrowseQuery query;
  const CategoryListScreen({super.key, required this.title, required this.query});
  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  final _scroll = ScrollController();
  late BrowseQuery _q;
  String _keyword = '';
  final Set<String> _langs = {}; // rỗng = mọi loại; chứa: phude/thuyetminh/longtieng (chọn nhiều)
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _q = widget.query;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(browseProvider(_q).notifier).loadMore();
      }
    });
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      // CHỈ màn đang ở TRÊN CÙNG được xử lý — xem chú thích ở detail_screen.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false) && Navigator.canPop(context)) {
        Navigator.pop(context);
        return true;
      }
    }
    return false;
  }

  void _onKeyword(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _keyword = v);
    });
  }

  // Lọc theo loại tiếng (phía app). Chọn nhiều -> khớp 1 trong các loại đã chọn.
  List<Movie> _applyLang(List<Movie> items) {
    if (_langs.isEmpty) return items;
    return items.where((m) =>
        (_langs.contains('phude') && m.hasPhuDe) ||
        (_langs.contains('thuyetminh') && m.hasThuyetMinh) ||
        (_langs.contains('longtieng') && m.hasLongTieng)).toList();
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
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title)),
      body: Column(children: [
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
        if (!searching) TvFilterBar(current: _q, onChanged: (q) => setState(() => _q = q)),
        LangFilterRow(
          selected: _langs,
          onChanged: (s) => setState(() {
            _langs
              ..clear()
              ..addAll(s);
          }),
        ),
        Expanded(
          child: searching
              ? AsyncView(
                  value: ref.watch(searchProvider(_keyword)),
                  onRetry: () => ref.invalidate(searchProvider(_keyword)),
                  skeleton: const MovieGridSkeleton(),
                  builder: (list) {
                    final f = _applyLang(list);
                    return f.isEmpty
                        ? const Center(child: Text('Không tìm thấy phim', style: TextStyle(color: Colors.white38)))
                        : _grid(f);
                  },
                )
              : _browseBody(),
        ),
      ]),
    );
  }

  Widget _browseBody() {
    final st = ref.watch(browseProvider(_q));
    if (st.items.isEmpty && st.loading) return const MovieGridSkeleton();
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
