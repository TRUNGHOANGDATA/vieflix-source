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
  int? _userServer; // null = chưa chọn -> dùng mặc định (ưu tiên Thuyết minh)

  int _defaultServer(List<ServerGroup> servers) {
    for (int i = 0; i < servers.length; i++) {
      final n = servers[i].serverName.toLowerCase();
      if (n.contains('thuyết minh') || n.contains('thuyet minh') ||
          n.contains('lồng tiếng') || n.contains('long tieng')) {
        return i;
      }
    }
    return 0;
  }

  int _effServer(List<ServerGroup> servers) {
    final u = _userServer;
    if (u != null && u >= 0 && u < servers.length) return u;
    return _defaultServer(servers);
  }

  // Sắp xếp tập theo số thứ tự (Tập 1,2,...,10,11 thay vì 1,10,11,2)
  List<Episode> _sorted(List<Episode> items) {
    int? num(String s) {
      final m = RegExp(r'\d+').firstMatch(s);
      return m == null ? null : int.tryParse(m.group(0)!);
    }
    final copy = [...items];
    copy.sort((a, b) {
      final na = num(a.name), nb = num(b.name);
      if (na != null && nb != null) return na.compareTo(nb);
      if (na != null) return -1;
      if (nb != null) return 1;
      return a.name.compareTo(b.name);
    });
    return copy;
  }

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
    final srv = hasServer ? _effServer(servers) : 0;
    final eps = hasServer ? _sorted(servers[srv].items) : <Episode>[];
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
              onPressed: hasServer ? () => _play(d, servers[srv], eps, eps.first) : null,
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
            // Chọn server (kèm số tập). Mặc định ưu tiên Thuyết minh.
            Wrap(spacing: 8, children: [
              for (int i = 0; i < servers.length; i++)
                ChoiceChip(
                  label: Text('${servers[i].serverName} · ${servers[i].items.length} tập'),
                  selected: srv == i,
                  selectedColor: kRed,
                  onSelected: (_) => setState(() => _userServer = i),
                ),
            ]),
            const SizedBox(height: 10),
            // Trạng thái phát: hiện có bao nhiêu tập + tình trạng cập nhật
            Row(children: [
              const Icon(Icons.playlist_play, color: Colors.white54, size: 20),
              const SizedBox(width: 6),
              Text(
                'Hiện có ${eps.length} tập'
                '${d.base.currentEpisode.isNotEmpty ? ' · ${d.base.currentEpisode}' : ''}'
                '${(d.base.totalEpisodes > eps.length) ? ' (dự kiến ${d.base.totalEpisodes} tập — đang cập nhật)' : ''}',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ]),
            const SizedBox(height: 12),
            // Lưới tập đều nhau, đã sắp xếp theo số thứ tự
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final ep in eps)
                SizedBox(
                  width: 68,
                  child: ActionChip(
                    backgroundColor: kSurface,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    label: Center(child: Text('Tập ${ep.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12))),
                    onPressed: () => _play(d, servers[srv], eps, ep),
                  ),
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

  void _play(MovieDetail d, ServerGroup s, List<Episode> eps, Episode ep) {
    final poster = d.thumbUrl.isNotEmpty ? d.thumbUrl : d.posterUrl;
    ref.read(storeProvider).saveProgress(slug: d.slug, name: d.name, poster: poster, server: s.serverName, episodeSlug: ep.slug, episodeName: ep.name);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        movieName: d.name,
        posterUrl: d.posterUrl.isNotEmpty ? d.posterUrl : d.thumbUrl,
        embedUrl: ep.embed,
        episodes: eps,
        startIndex: eps.indexOf(ep),
        onEpisodeChange: (e) => ref.read(storeProvider).saveProgress(slug: d.slug, name: d.name, poster: poster, server: s.serverName, episodeSlug: e.slug, episodeName: e.name),
      ),
    ));
  }
}
