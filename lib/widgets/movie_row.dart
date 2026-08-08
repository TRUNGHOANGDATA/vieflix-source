import 'package:flutter/material.dart';
import '../models/movie.dart';
import 'movie_card.dart';

class MovieRow extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final void Function(Movie) onTap;
  const MovieRow({super.key, required this.title, required this.movies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      SizedBox(
        height: 250,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: movies.length,
          itemBuilder: (c, i) => MovieCard(movie: movies[i], onTap: () => onTap(movies[i])),
        ),
      ),
    ]);
  }
}
