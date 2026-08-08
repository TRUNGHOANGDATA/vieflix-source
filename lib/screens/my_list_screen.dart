import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

class MyListScreen extends ConsumerWidget {
  const MyListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(storeProvider).favorites;
    if (favs.isEmpty) {
      return const Center(
        child: Text('Chưa có phim yêu thích.\nBấm ♥ ở trang chi tiết để lưu.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white38)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, childAspectRatio: 0.52, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: favs.length,
      itemBuilder: (c, i) {
        final m = favs[i];
        return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
      },
    );
  }
}
