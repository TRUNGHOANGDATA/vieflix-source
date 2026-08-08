import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/async_view.dart';
import 'detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _q = '';

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
          onSubmitted: (v) => setState(() => _q = v),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      Expanded(
        child: _q.trim().length < 2
            ? const Center(child: Text('Nhập ít nhất 2 ký tự để tìm', style: TextStyle(color: Colors.white38)))
            : AsyncView(
                value: ref.watch(searchProvider(_q)),
                onRetry: () => ref.invalidate(searchProvider(_q)),
                builder: (list) => list.isEmpty
                    ? const Center(child: Text('Không tìm thấy phim', style: TextStyle(color: Colors.white38)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, childAspectRatio: 0.52, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final m = list[i];
                          return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
                        },
                      ),
              ),
      ),
    ]);
  }
}
