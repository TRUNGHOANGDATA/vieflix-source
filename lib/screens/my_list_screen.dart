import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/tv_focusable.dart';
import 'detail_screen.dart';

class MyListScreen extends ConsumerStatefulWidget {
  const MyListScreen({super.key});
  @override
  ConsumerState<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends ConsumerState<MyListScreen> {
  String? _genre; // null = Tất cả

  /// Bỏ khỏi yêu thích rồi báo các màn vẽ lại.
  Future<void> _unfav(Movie m) async {
    await ref.read(storeProvider).toggleFavorite(m);
    ref.read(homeRefreshProvider.notifier).state++;
  }

  /// TV: hỏi lại trước khi bỏ (remote dễ bấm nhầm).
  Future<void> _confirmUnfav(Movie m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Bỏ khỏi yêu thích?', style: TextStyle(color: Colors.white)),
        content: Text('Xoá "${m.name}" khỏi danh sách Yêu thích.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Giữ lại')),
          ElevatedButton(autofocus: true, onPressed: () => Navigator.pop(c, true), child: const Text('Bỏ thích')),
        ],
      ),
    );
    if (ok == true) await _unfav(m);
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ storeProvider giữ CÙNG một đối tượng nên watch nó không bao giờ báo vẽ
    // lại. Bỏ thích ở trang chi tiết xong quay về, phim vẫn nằm đây -> người dùng
    // tưởng không bỏ được (lỗi 10/2026). Phải nghe homeRefreshProvider.
    ref.watch(homeRefreshProvider);
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
                // TV cao thêm chỗ cho nút "Bỏ thích" dưới thẻ.
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: Platform.isAndroid ? 0.52 : 0.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8),
                itemCount: filtered.length,
                itemBuilder: (c, i) => _favCard(c, filtered[i]),
              ),
      ),
    ]);
  }

  Widget _favCard(BuildContext c, Movie stored) {
    // Phim lưu thiếu link ảnh (gặp ở bản lưu cũ / nhận qua đồng bộ) thì lấy ảnh
    // từ thông tin phim, khỏi hiện ô xám.
    var m = stored;
    if (m.thumbUrl.isEmpty && m.posterUrl.isEmpty) {
      final d = ref.watch(detailProvider(m.slug)).maybeWhen(data: (d) => d, orElse: () => null);
      if (d != null) {
        m = Movie.fromJson({
          'name': m.name, 'slug': m.slug, 'thumb_url': d.thumbUrl, 'poster_url': d.posterUrl,
          'quality': m.quality, 'current_episode': m.currentEpisode,
          'total_episodes': m.totalEpisodes, 'genres': m.genres,
        });
      }
    }
    final card = MovieCard(
      movie: m,
      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))),
    );
    if (Platform.isAndroid) {
      // Remote không trỏ được nút nhỏ ở góc -> nút "Bỏ thích" ngay dưới thẻ:
      // ▼ từ thẻ là tới, OK là bỏ.
      return Column(children: [
        Expanded(child: card),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: FocusHighlight(
            scale: 1.0,
            onPressed: () => _confirmUnfav(stored),
            builder: (f) => Container(
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: f ? kRed : Colors.white12,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: f ? kRed : Colors.white24, width: 2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.heart_broken, size: 15, color: f ? Colors.white : Colors.white70),
                const SizedBox(width: 4),
                Text('Bỏ thích',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: f ? Colors.white : Colors.white70)),
              ]),
            ),
          ),
        ),
      ]);
    }
    // PC: nút ✕ ở góc trái-trên (góc phải đã có nhãn chất lượng).
    return Stack(children: [
      Positioned.fill(child: card),
      Positioned(
        top: 6, left: 12,
        child: Tooltip(
          message: 'Bỏ khỏi yêu thích',
          child: GestureDetector(
            onTap: () => _unfav(stored),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ),
    ]);
  }
}
