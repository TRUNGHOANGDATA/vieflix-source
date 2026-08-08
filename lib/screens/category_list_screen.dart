import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/filter_bar.dart';
import '../widgets/async_view.dart';
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

  @override
  void initState() {
    super.initState();
    _q = widget.query;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(browseProvider(_q).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
            onChanged: (v) => setState(() => _keyword = v),
          ),
        ),
        if (!searching) FilterBar(current: _q, onChanged: (q) => setState(() => _q = q)),
        Expanded(
          child: searching
              ? AsyncView(
                  value: ref.watch(searchProvider(_keyword)),
                  onRetry: () => ref.invalidate(searchProvider(_keyword)),
                  builder: (list) => list.isEmpty
                      ? const Center(child: Text('Không tìm thấy phim', style: TextStyle(color: Colors.white38)))
                      : _grid(list),
                )
              : _browseBody(),
        ),
      ]),
    );
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
      Expanded(child: _grid(st.items)),
      if (st.loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: kRed)),
    ]);
  }
}
