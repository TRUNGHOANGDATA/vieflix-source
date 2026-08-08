import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';

class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback onTap;
  final double width;
  const MovieCard({super.key, required this.movie, required this.onTap, this.width = 150});
  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _hover = false;
  void _set(bool v) => setState(() => _hover = v);

  @override
  Widget build(BuildContext context) {
    final img = widget.movie.thumbUrl.isNotEmpty ? widget.movie.thumbUrl : widget.movie.posterUrl;
    return FocusableActionDetector(
      onShowHoverHighlight: _set,
      onShowFocusHighlight: _set,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.onTap(); return null; }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.width,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _hover ? kRed : Colors.transparent, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: CachedNetworkImage(
                    imageUrl: img, fit: BoxFit.cover,
                    placeholder: (c, _) => Container(color: kSurface),
                    errorWidget: (c, _, __) => Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.white24)),
                  ),
                ),
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.all(4),
                  child: Text(widget.movie.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
