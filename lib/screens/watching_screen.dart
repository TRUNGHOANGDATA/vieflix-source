import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import 'home_screen.dart'; // dùng lại ContinueCard
import 'detail_screen.dart';

/// Tab "Đang xem": lưới phim đang xem dở (giống bố cục Thư viện phim).
class WatchingScreen extends ConsumerWidget {
  const WatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeRefreshProvider); // vẽ lại khi xem thêm / xoá mục
    final cw = ref.watch(storeProvider).continueWatching;
    if (cw.isEmpty) {
      return const Center(
        child: Text('Chưa có phim đang xem dở.\nVào xem một phim, nó sẽ hiện ở đây.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 15)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('Đang xem', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200, childAspectRatio: 0.62, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: cw.length,
          itemBuilder: (c, i) => ContinueCard(
            progress: cw[i],
            onOpen: (slug, name) => Navigator.push(context,
                MaterialPageRoute(builder: (_) => DetailScreen(slug: slug, title: name))),
          ),
        ),
      ),
    ]);
  }
}
