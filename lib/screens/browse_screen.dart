import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/catalog.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/filter_bar.dart';
import 'detail_screen.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});
  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  BrowseQuery _q = const BrowseQuery('type', 'phim-bo');
  final _scroll = ScrollController();

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
    _scroll.dispose();
    super.dispose();
  }

  String _label(BrowseQuery q) {
    switch (q.kind) {
      case 'type': return kTypes.firstWhere((e) => e.slug == q.value, orElse: () => CatalogEntry(q.value, q.value)).label;
      case 'genre': return kGenres.firstWhere((e) => e.slug == q.value, orElse: () => CatalogEntry(q.value, q.value)).label;
      case 'country': return kCountries.firstWhere((e) => e.slug == q.value, orElse: () => CatalogEntry(q.value, q.value)).label;
      default: return 'Năm ${q.value}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(browseProvider(_q));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (st.page < st.totalPage && !st.loading && _scroll.hasClients &&
          _scroll.position.maxScrollExtent < 400) {
        ref.read(browseProvider(_q).notifier).loadMore();
      }
    });
    return Column(children: [
      FilterBar(current: _q, onChanged: (q) => setState(() => _q = q)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(children: [
          Text(_label(_q), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('(${st.items.length} phim)', style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ]),
      ),
      Expanded(
        child: GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: st.items.length,
          itemBuilder: (c, i) {
            final m = st.items[i];
            return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
          },
        ),
      ),
      if (st.loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: kRed)),
    ]);
  }
}
