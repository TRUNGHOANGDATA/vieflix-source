import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/movie.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

/// Trang xem tất cả cho một DANH SÁCH CÓ SẴN (vd "Phim đề cử điểm cao") —
/// khác CategoryListScreen vốn tải theo danh mục + phân trang.
class MovieGridScreen extends StatefulWidget {
  final String title;
  final List<Movie> movies;
  const MovieGridScreen({super.key, required this.title, required this.movies});
  @override
  State<MovieGridScreen> createState() => _MovieGridScreenState();
}

class _MovieGridScreenState extends State<MovieGridScreen> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      // CHỈ màn đang ở TRÊN CÙNG được xử lý — xem chú thích ở detail_screen.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false) && Navigator.canPop(context)) {
        Navigator.pop(context);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title)),
      body: widget.movies.isEmpty
          ? const Center(child: Text('Chưa có phim', style: TextStyle(color: Colors.white38)))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: widget.movies.length,
              itemBuilder: (c, i) {
                final m = widget.movies[i];
                return MovieCard(
                  movie: m,
                  onTap: () => Navigator.push(
                      c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))),
                );
              },
            ),
    );
  }
}
