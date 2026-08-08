import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import 'movie_card.dart';

class MovieRow extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final void Function(Movie) onTap;
  final VoidCallback? onSeeMore;
  const MovieRow({
    super.key,
    required this.title,
    required this.movies,
    required this.onTap,
    this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onSeeMore,
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          if (onSeeMore != null)
            TextButton(
              onPressed: onSeeMore,
              child: const Text('Xem tất cả ›', style: TextStyle(color: kRed, fontSize: 14)),
            ),
        ]),
      ),
      SizedBox(
        height: 250,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: movies.length + (onSeeMore != null ? 1 : 0),
          itemBuilder: (c, i) {
            if (i >= movies.length) {
              // Thẻ "Xem thêm" cuối hàng
              return _SeeMoreCard(onTap: onSeeMore!);
            }
            return MovieCard(movie: movies[i], onTap: () => onTap(movies[i]));
          },
        ),
      ),
    ]);
  }
}

class _SeeMoreCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeMoreCard({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.arrow_forward, color: kRed, size: 36),
          SizedBox(height: 8),
          Text('Xem thêm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
