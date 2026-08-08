import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/catalog.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/async_view.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _q = '';

  void _browse(String title, BrowseQuery query) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => CategoryListScreen(title: title, query: query)));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tìm phim theo tên...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            filled: true, fillColor: kSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      Expanded(
        child: _q.trim().length < 2 ? _browseHub() : _results(),
      ),
    ]);
  }

  // Khi chưa gõ gì: cho duyệt nhanh theo Thể loại / Quốc gia
  Widget _browseHub() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Tìm theo thể loại', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in kGenres)
          ActionChip(
            backgroundColor: kSurface,
            label: Text(g.label, style: const TextStyle(color: Colors.white)),
            onPressed: () => _browse(g.label, BrowseQuery('genre', g.slug)),
          ),
      ]),
      const SizedBox(height: 24),
      const Text('Tìm theo quốc gia', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in kCountries)
          ActionChip(
            backgroundColor: kSurface,
            label: Text(c.label, style: const TextStyle(color: Colors.white)),
            onPressed: () => _browse('Phim ${c.label}', BrowseQuery('country', c.slug)),
          ),
      ]),
      const SizedBox(height: 24),
      const Text('Tìm theo năm', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final y in kYears)
          ActionChip(
            backgroundColor: kSurface,
            label: Text(y, style: const TextStyle(color: Colors.white)),
            onPressed: () => _browse('Phim năm $y', BrowseQuery('year', y)),
          ),
      ]),
    ]);
  }

  Widget _results() {
    return AsyncView(
      value: ref.watch(searchProvider(_q)),
      onRetry: () => ref.invalidate(searchProvider(_q)),
      builder: (list) => list.isEmpty
          ? const Center(child: Text('Không tìm thấy phim', style: TextStyle(color: Colors.white38)))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: list.length,
              itemBuilder: (c, i) {
                final m = list[i];
                return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
              },
            ),
    );
  }
}
