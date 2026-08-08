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

  void _go(int i) {
    if (!_controller.hasClients || widget.movies.isEmpty) return;
    final n = widget.movies.length;
    final target = (i % n + n) % n;
    _controller.animateToPage(target, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
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
        // Chấm chỉ vị trí + nút chuyển trái/phải (góc phải dưới)
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
            const SizedBox(width: 16),
            _arrow(Icons.chevron_left, () => _go(_current - 1)),
            const SizedBox(width: 8),
            _arrow(Icons.chevron_right, () => _go(_current + 1)),
          ]),
        ),
      ]),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70, width: 1.5),
          color: Colors.black26,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
