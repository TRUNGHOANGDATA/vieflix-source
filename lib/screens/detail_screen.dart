import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie_detail.dart';
import '../models/episode.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/async_view.dart';
import '../widgets/movie_row.dart';
import '../player/player_screen.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final String slug, title;
  const DetailScreen({super.key, required this.slug, required this.title});
  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  int _server = 0;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(detailProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title)),
      body: AsyncView<MovieDetail>(
        value: detail,
        onRetry: () => ref.invalidate(detailProvider(widget.slug)),
        builder: (d) => _content(d),
      ),
    );
  }

  Widget _content(MovieDetail d) {
    final store = ref.watch(storeProvider);
    final fav = store.isFavorite(d.slug);
    final servers = d.servers;
    final hasServer = servers.isNotEmpty;
    if (_server >= servers.length) _server = 0;
    return ListView(children: [
      SizedBox(
        height: 320,
        child: Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(imageUrl: d.posterUrl, fit: BoxFit.cover, errorWidget: (c, _, __) => Container(color: kSurface)),
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [kBg, Colors.transparent]))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (d.year != null) _chip(d.year!),
            if (d.base.quality.isNotEmpty) _chip(d.base.quality),
            for (final g in d.genres.take(3)) _chip(g.name),
            for (final c in d.countries.take(1)) _chip(c.name),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: hasServer ? () => _play(d, servers[_server], servers[_server].items.first) : null,
              icon: const Icon(Icons.play_arrow), label: const Text('Xem ngay'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () async { await store.toggleFavorite(d.base); setState(() {}); },
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? kRed : Colors.white),
              label: Text(fav ? 'Đã thích' : 'Yêu thích', style: const TextStyle(color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 16),
          if (d.director != null) Text('Đạo diễn: ${d.director}', style: const TextStyle(color: Colors.white70)),
          if (d.casts != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Diễn viên: ${d.casts}', style: const TextStyle(color: Colors.white70))),
          const SizedBox(height: 12),
          Text(d.description, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 20),
          if (hasServer) ...[
            Wrap(spacing: 8, children: [
              for (int i = 0; i < servers.length; i++)
                ChoiceChip(
                  label: Text(servers[i].serverName),
                  selected: _server == i,
                  selectedColor: kRed,
                  onSelected: (_) => setState(() => _server = i),
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final ep in servers[_server].items)
                ActionChip(
                  backgroundColor: kSurface,
                  label: Text('Tập ${ep.name}', style: const TextStyle(color: Colors.white)),
                  onPressed: () => _play(d, servers[_server], ep),
                ),
            ]),
          ] else
            const Text('Phim chưa có nguồn phát.', style: TextStyle(color: Colors.white54)),
        ]),
      ),
      if (d.genres.isNotEmpty) _similar(d),
      const SizedBox(height: 30),
    ]);
  }

  Widget _chip(String s) => Chip(
      label: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: kSurface, visualDensity: VisualDensity.compact);

  Widget _similar(MovieDetail d) {
    final v = ref.watch(genreRowProvider(d.genres.first.slug));
    return v.maybeWhen(
      data: (list) => MovieRow(
        title: 'Phim tương tự',
        movies: list.where((m) => m.slug != d.slug).toList(),
        onTap: (m) => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _play(MovieDetail d, ServerGroup s, Episode ep) {
    ref.read(storeProvider).saveProgress(slug: d.slug, server: s.serverName, episodeSlug: ep.slug, episodeName: ep.name);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        title: '${d.name} - Tập ${ep.name}',
        embedUrl: ep.embed,
        episodes: s.items,
        startIndex: s.items.indexOf(ep),
        onEpisodeChange: (e) => ref.read(storeProvider).saveProgress(slug: d.slug, server: s.serverName, episodeSlug: e.slug, episodeName: e.name),
      ),
    ));
  }
}
