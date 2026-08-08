import 'dart:async';
import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import 'hero_banner.dart';

/// Banner lớn tự trượt qua vài phim nổi bật.
class HeroCarousel extends StatefulWidget {
  final List<Movie> movies;
  final void Function(Movie) onOpen;
  const HeroCarousel({super.key, required this.movies, required this.onOpen});
  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_controller.hasClients || widget.movies.isEmpty) return;
      final next = (_current + 1) % widget.movies.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies;
    if (movies.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 460,
      child: Stack(children: [
        PageView.builder(
          controller: _controller,
          itemCount: movies.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (c, i) => HeroBanner(
            movie: movies[i],
            onPlay: () => widget.onOpen(movies[i]),
            onInfo: () => widget.onOpen(movies[i]),
          ),
        ),
        // Chấm chỉ vị trí
        Positioned(
          bottom: 20, right: 40,
          child: Row(children: [
            for (int i = 0; i < movies.length; i++)
              Container(
                width: _current == i ? 22 : 8, height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _current == i ? kRed : Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
