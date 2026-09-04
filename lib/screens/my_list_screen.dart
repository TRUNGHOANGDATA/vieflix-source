import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

class MyListScreen extends ConsumerStatefulWidget {
  const MyListScreen({super.key});
  @override
  ConsumerState<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends ConsumerState<MyListScreen> {
  String? _genre; // null = Tất cả

  @override
  Widget build(BuildContext context) {
    final favs = onlyEnabledSources(ref.watch(storeProvider).favorites,
            ref.watch(enabledSourcesProvider), (m) => m.slug)
        .toList();
    if (favs.isEmpty) {
      return const Center(
        child: Text('Chưa có phim yêu thích.\nBấm ♥ ở trang chi tiết để lưu.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white38)),
      );
    }
    // Tập hợp thể loại có trong danh sách yêu thích
    final genres = <String>{};
    for (final m in favs) {
      genres.addAll(m.genres);
    }
    final genreList = genres.toList()..sort();
    final filtered = _genre == null ? favs : favs.where((m) => m.genres.contains(_genre)).toList();

    return Column(children: [
      if (genreList.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: _genre == null,
              selectedColor: kRed,
              onSelected: (_) => setState(() => _genre = null),
            ),
            const SizedBox(width: 8),
            for (final g in genreList) ...[
              ChoiceChip(
                label: Text(g),
                selected: _genre == g,
                selectedColor: kRed,
                onSelected: (_) => setState(() => _genre = g),
              ),
              const SizedBox(width: 8),
            ],
          ]),
        ),
      Expanded(
        child: filtered.isEmpty
            ? const Center(child: Text('Không có phim trong thể loại này', style: TextStyle(color: Colors.white38)))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: filtered.length,
                itemBuilder: (c, i) {
                  final m = filtered[i];
                  return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
                },
              ),
      ),
    ]);
  }
}
