import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';

class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback onTap;
  final double width;
  const MovieCard({super.key, required this.movie, required this.onTap, this.width = 180});
  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _hover = false;
  void _set(bool v) => setState(() => _hover = v);

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final img = m.thumbUrl.isNotEmpty ? m.thumbUrl : m.posterUrl;
    return FocusableActionDetector(
      onShowHoverHighlight: _set,
      onShowFocusHighlight: _set,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.onTap(); return null; }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hover ? kRed : Colors.transparent, width: 2),
            boxShadow: _hover ? [const BoxShadow(color: kRed, blurRadius: 12, spreadRadius: 1)] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(
                    imageUrl: img, fit: BoxFit.cover,
                    placeholder: (c, _) => Container(color: kSurface),
                    errorWidget: (c, _, __) => Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.white24)),
                  ),
                  if (m.quality.isNotEmpty)
                    Positioned(
                      top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(4)),
                        child: Text(m.quality, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (m.currentEpisode.isNotEmpty)
                    Positioned(
                      left: 4, right: 4, bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(4)),
                        child: Text(m.currentEpisode, maxLines: 1, overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                  if (_hover)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                ]),
              ),
              Container(
                color: Colors.black,
                padding: const EdgeInsets.all(6),
                child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
