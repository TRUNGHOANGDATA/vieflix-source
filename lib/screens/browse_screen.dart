import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/catalog.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
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

  void _pick(BrowseQuery q) => setState(() => _q = q);

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(browseProvider(_q));
    return Column(children: [
      _filterBar(),
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
    ]);
  }

  Widget _filterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        _group('Loại', [for (final t in kTypes) BrowseQuery('type', t.slug)], [for (final t in kTypes) t.label]),
        _group('Thể loại', [for (final g in kGenres) BrowseQuery('genre', g.slug)], [for (final g in kGenres) g.label]),
        _group('Quốc gia', [for (final c in kCountries) BrowseQuery('country', c.slug)], [for (final c in kCountries) c.label]),
        _group('Năm', [for (final y in kYears) BrowseQuery('year', y)], kYears),
      ]),
    );
  }

  Widget _group(String label, List<BrowseQuery> qs, List<String> labels) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(color: Colors.white54)),
        for (int i = 0; i < qs.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: _q == qs[i],
              selectedColor: kRed,
              onSelected: (_) => _pick(qs[i]),
            ),
          ),
      ]),
    );
  }
}
