import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/episode.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/async_view.dart';
import '../widgets/movie_row.dart';
import '../widgets/tv_focusable.dart';
import '../player/player_screen.dart';
import 'category_list_screen.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final String slug, title;
  const DetailScreen({super.key, required this.slug, required this.title});
  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  int? _userServer; // null = chưa chọn -> dùng mặc định (ưu tiên Thuyết minh)

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
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        return true;
      }
    }
    return false;
  }

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

  // Tên tập hiển thị: KKPhim đã có sẵn "Tập 01", nguonc chỉ có "1" -> tránh "Tập Tập"
  String _epLabel(String name) {
    final n = name.trim();
    if (RegExp(r'^t[aậ]p\b', caseSensitive: false).hasMatch(n)) return n;
    if (RegExp(r'^\d').hasMatch(n)) return 'Tập $n';
    return n;
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
      extendBodyBehindAppBar: true, // để ảnh nền tràn lên sau thanh tiêu đề
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        // Không đặt tiêu đề ở đây: AppBar trong suốt nằm cố định, cuộn lên sẽ đè
        // chữ lên nội dung nhìn rất xấu. Tên phim đã hiện to trong header rồi.
      ),
      body: AsyncView<MovieDetail>(
        value: detail,
        onRetry: () => ref.invalidate(detailProvider(widget.slug)),
        builder: (d) => _content(d),
      ),
    );
  }

  /// Ảnh nền lớn cho phần đầu trang chi tiết (backdrop TMDB, không có thì dùng
  /// poster/thumb), phủ các lớp mờ để chữ + poster nổi rõ và hoà vào nền trang.
  Widget _detailBackdrop(MovieDetail d) {
    final q = d.base.originalName.isNotEmpty ? d.base.originalName : d.name;
    final backdrop = ref.watch(backdropProvider(q)).maybeWhen(data: (u) => u, orElse: () => null);
    final bg = (backdrop != null && backdrop.isNotEmpty)
        ? backdrop
        : (d.thumbUrl.isNotEmpty ? d.thumbUrl : d.posterUrl);
    return Stack(fit: StackFit.expand, children: [
      CachedNetworkImage(
        imageUrl: bg, fit: BoxFit.cover, alignment: Alignment.topCenter, memCacheWidth: 1280,
        placeholder: (c, _) => Container(color: kSurface),
        errorWidget: (c, _, __) => Container(color: kSurface),
      ),
      Container(color: Colors.black.withValues(alpha: 0.45)),
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [kBg, Colors.transparent], stops: [0.05, 0.9]),
        ),
      ),
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: [Colors.black87, Colors.transparent], stops: [0.0, 0.7]),
        ),
      ),
    ]);
  }

  Widget _content(MovieDetail d) {
    final store = ref.watch(storeProvider);
    final fav = store.isFavorite(d.slug);
    final servers = d.servers;
    final hasServer = servers.isNotEmpty;
    final srv = hasServer ? _effServer(servers) : 0;
    final eps = hasServer ? _sorted(servers[srv].items) : <Episode>[];
    return ListView(padding: EdgeInsets.zero, children: [
      // Header điện ảnh: ảnh nền lớn + lớp mờ, poster & thông tin nổi lên trên.
      Stack(children: [
        Positioned.fill(child: _detailBackdrop(d)),
        Padding(
        padding: EdgeInsets.fromLTRB(32, MediaQuery.of(context).padding.top + kToolbarHeight + 16, 32, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: d.thumbUrl.isNotEmpty ? d.thumbUrl : d.posterUrl,
              width: 260, height: 380, fit: BoxFit.cover,
              placeholder: (c, _) => Container(width: 260, height: 380, color: kSurface),
              errorWidget: (c, _, __) => Container(width: 260, height: 380, color: kSurface, child: const Icon(Icons.movie, color: Colors.white24, size: 48)),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.15)),
              if (d.base.originalName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(d.base.originalName, style: const TextStyle(color: Colors.amber, fontSize: 15)),
                ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (d.year != null) _navChip(d.year!, 'Phim năm ${d.year}', BrowseQuery('year', d.year!)),
                if (d.base.quality.isNotEmpty) _chip(d.base.quality),
                for (final g in d.genres.take(3)) _navChip(g.name, g.name, BrowseQuery('genre', g.slug)),
                for (final c in d.countries.take(1)) _navChip(c.name, 'Phim ${c.name}', BrowseQuery('country', c.slug)),
              ]),
              _ratingLine(d),
              const SizedBox(height: 18),
              Row(children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: kRed, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16)),
                  onPressed: hasServer ? () => _playSmart(d, servers[srv], eps) : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Xem ngay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () async {
                    final favMovie = Movie.fromJson({
                      'name': d.name, 'slug': d.slug,
                      'poster_url': d.posterUrl, 'thumb_url': d.thumbUrl,
                      'quality': d.base.quality, 'current_episode': d.base.currentEpisode,
                      'total_episodes': d.base.totalEpisodes,
                      'genres': d.genres.map((g) => g.name).toList(),
                    });
                    await store.toggleFavorite(favMovie);
                    setState(() {});
                  },
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? kRed : Colors.white),
                  label: Text(fav ? 'Đã thích' : 'Yêu thích', style: const TextStyle(color: Colors.white)),
                ),
              ]),
              const SizedBox(height: 16),
              if (d.director != null) Text('Đạo diễn: ${d.director}', style: const TextStyle(color: Colors.white70)),
              if (d.casts != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Diễn viên: ${d.casts}', style: const TextStyle(color: Colors.white70))),
              const SizedBox(height: 12),
              // TV: mô tả dài phải cuộn được bằng remote (đoạn văn thường không
              // "chọn" được bằng D-pad). PC vẫn hiện đầy đủ như cũ.
              Platform.isAndroid
                  ? TvScrollableText(text: d.description)
                  : Text(d.description, style: const TextStyle(color: Colors.white70, height: 1.5)),
            ]),
          ),
        ]),
        ),
      ]),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasServer) ...[
            // Chọn server (kèm số tập). Mặc định ưu tiên Thuyết minh.
            // Dùng FocusHighlight để remote TV chọn rõ + tự cuộn tới.
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (int i = 0; i < servers.length; i++)
                FocusHighlight(
                  scale: 1.0,
                  onPressed: () => setState(() => _userServer = i),
                  builder: (f) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: srv == i ? kRed : kSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: f ? kAmber : Colors.transparent, width: 2),
                    ),
                    child: Text('${servers[i].serverName} · ${servers[i].items.length} tập',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: srv == i ? FontWeight.bold : FontWeight.normal)),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            // Trạng thái phát: X / tổng số tập (vd 6 / 18)
            Builder(builder: (_) {
              final total = d.base.totalEpisodes > eps.length ? d.base.totalEpisodes : eps.length;
              final updating = d.base.totalEpisodes > eps.length;
              return Row(children: [
                const Icon(Icons.playlist_play, color: Colors.white54, size: 20),
                const SizedBox(width: 6),
                Text('${eps.length} / $total tập', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text(updating ? '· Đang cập nhật' : '· Đã hoàn tất', style: TextStyle(color: updating ? Colors.orangeAccent : Colors.greenAccent, fontSize: 12)),
              ]);
            }),
            const SizedBox(height: 12),
            // Lưới tập đều nhau, đã sắp xếp theo số thứ tự.
            // FocusHighlight: remote chọn rõ (viền vàng) + TỰ CUỘN tới khi lên/xuống.
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final ep in eps)
                SizedBox(
                  width: 72,
                  child: FocusHighlight(
                    scale: 1.0,
                    onPressed: () => _play(d, servers[srv], eps, ep),
                    builder: (f) => Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: f ? kRed : kSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: f ? kAmber : Colors.white10, width: 2),
                      ),
                      child: Text(_epLabel(ep.name),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white, fontSize: 12,
                              fontWeight: f ? FontWeight.bold : FontWeight.normal)),
                    ),
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

  Widget _ratingLine(MovieDetail d) {
    final q = d.base.originalName.isNotEmpty ? d.base.originalName : d.name;
    final rating = ref.watch(tmdbRatingProvider(q));
    return rating.maybeWhen(
      data: (res) => res == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                const Icon(Icons.star, color: Colors.amber, size: 22),
                const SizedBox(width: 4),
                Text(res.rating.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('/10', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 8),
                Text('TMDB · ${res.votes} lượt đánh giá', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _chip(String s) => Chip(
      label: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: kSurface, visualDensity: VisualDensity.compact);

  // Chip bấm được -> mở danh sách theo năm/thể loại/quốc gia
  Widget _navChip(String label, String title, BrowseQuery query) => ActionChip(
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: kSurface,
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => CategoryListScreen(title: title, query: query))),
      );

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

  Future<void> _saveAndRefresh(MovieDetail d, ServerGroup s, Episode ep, String poster) async {
    // await để ghi xuống đĩa xong hẳn -> không mất khi đóng app đột ngột
    await ref.read(storeProvider).saveProgress(
        slug: d.slug, name: d.name, poster: poster,
        server: s.serverName, episodeSlug: ep.slug, episodeName: ep.name);
    // Báo trang chủ cập nhật lại hàng "Xem tiếp" ngay
    ref.read(homeRefreshProvider.notifier).state++;
  }

  /// Bấm "Xem ngay": nếu phim đang xem dở thì HỎI xem tiếp tập cũ hay xem từ đầu.
  /// Nút "Xem tiếp" được chọn sẵn -> trên TV chỉ cần bấm OK.
  Future<void> _playSmart(MovieDetail d, ServerGroup s, List<Episode> eps) async {
    if (eps.isEmpty) return;
    // App chỉ mở ĐÚNG TẬP đang xem dở. VỊ TRÍ trong tập do NGUỒN (nguonc) tự nhớ:
    // khi mở lại, trang nguồn hiện hộp "Bạn đã dừng lại ở ..." và app tự bấm
    // "Tiếp tục xem" hộ (remote không bấm được nút web). App KHÔNG tự tua/hỏi lại
    // nữa để khỏi đá nhau với cơ chế nhớ của nguồn.
    final p = ref.read(storeProvider).progressFor(d.slug);
    var idx = 0;
    if (p != null) {
      final i = eps.indexWhere((e) => e.slug == p.episodeSlug);
      if (i >= 0) idx = i;
    }
    _play(d, s, eps, eps[idx]);
  }

  void _play(MovieDetail d, ServerGroup s, List<Episode> eps, Episode ep, {double startPosition = 0}) {
    final poster = d.thumbUrl.isNotEmpty ? d.thumbUrl : d.posterUrl;
    _saveAndRefresh(d, s, ep, poster);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        movieName: d.name,
        embedUrl: ep.embed,
        episodes: eps,
        startIndex: eps.indexOf(ep),
        totalEpisodes: d.base.totalEpisodes > eps.length ? d.base.totalEpisodes : eps.length,
        startPosition: startPosition,
        onEpisodeChange: (e) => _saveAndRefresh(d, s, e, poster),
        onPosition: (pos, dur) => ref.read(storeProvider).savePosition(d.slug, pos, dur),
      ),
    ));
  }
}
