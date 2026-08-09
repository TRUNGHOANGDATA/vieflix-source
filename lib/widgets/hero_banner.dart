import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';

class HeroBanner extends StatelessWidget {
  final Movie movie;
  final VoidCallback onPlay;
  final VoidCallback onInfo;
  const HeroBanner({super.key, required this.movie, required this.onPlay, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(
          imageUrl: movie.posterUrl.isNotEmpty ? movie.posterUrl : movie.thumbUrl,
          fit: BoxFit.cover,
          memCacheWidth: 1280,
          errorWidget: (c, _, __) => Container(color: kSurface),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: [Colors.black, Colors.black54, Colors.transparent],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.center,
              colors: [kBg, Colors.transparent],
            ),
          ),
        ),
        Positioned(
          left: 40, bottom: 60, right: 300,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(movie.name, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Text(movie.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 16),
            Row(children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kRed, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                onPressed: onPlay, icon: const Icon(Icons.play_arrow), label: const Text('Xem ngay'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                onPressed: onInfo, icon: const Icon(Icons.info_outline), label: const Text('Chi tiết'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
