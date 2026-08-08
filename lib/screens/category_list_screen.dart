import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

/// Trang danh sách đầy đủ cho một danh mục (thể loại/quốc gia/loại), cuộn vô tận.
class CategoryListScreen extends ConsumerStatefulWidget {
  final String title;
  final BrowseQuery query;
  const CategoryListScreen({super.key, required this.title, required this.query});
  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(browseProvider(widget.query).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(browseProvider(widget.query));
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title)),
      body: Column(children: [
        Expanded(
          child: GridView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170, childAspectRatio: 0.52, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: st.items.length,
            itemBuilder: (c, i) {
              final m = st.items[i];
              return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
            },
          ),
        ),
        if (st.loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: kRed)),
      ]),
    );
  }
}
