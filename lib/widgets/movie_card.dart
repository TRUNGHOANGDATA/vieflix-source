import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'tv_focusable.dart';

/// Nhãn tập trên thẻ: "Tập 21" + biết tổng -> "Tập 21 / 32".
/// Giữ nguyên nếu đã có dạng x/y (Hoàn tất 16/16) hoặc phim lẻ (FULL).
String episodeLabel(Movie m) {
  final cur = m.currentEpisode.trim();
  if (cur.isEmpty) return '';
  if (cur.contains('/') || m.totalEpisodes <= 1) return cur;
  return '$cur / ${m.totalEpisodes}';
}

/// Bọc bất kỳ thẻ nào để có ô preview lớn khi rê chuột (dùng chung cho
/// thẻ phim thường lẫn thẻ "Xem tiếp"). builder(hovering) để thẻ tự vẽ
/// viền/hiệu ứng khi đang hover.
class HoverPreview extends ConsumerStatefulWidget {
  final Movie movie;
  final VoidCallback onOpen;
  final Widget Function(bool hovering) builder;
  const HoverPreview({super.key, required this.movie, required this.onOpen, required this.builder});
  @override
  ConsumerState<HoverPreview> createState() => _HoverPreviewState();
}

class _HoverPreviewState extends ConsumerState<HoverPreview> {
  final _key = GlobalKey();
  final _portal = OverlayPortalController();
  Timer? _showT, _hideT;
  bool _overCard = false, _overPreview = false;
  bool _focused = false; // được chọn bằng remote (D-pad)
  Rect _rect = Rect.zero;

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _key.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.5, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _showT?.cancel();
    _hideT?.cancel();
    super.dispose();
  }

  void _enter() {
    _overCard = true;
    setState(() {});
    _hideT?.cancel();
    _showT?.cancel();
    _showT = Timer(const Duration(milliseconds: 450), () {
      if (!_overCard || !mounted) return;
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      _rect = box.localToGlobal(Offset.zero) & box.size;
      _portal.show();
    });
  }

  void _exitCard() {
    _overCard = false;
    setState(() {});
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideT?.cancel();
    _hideT = Timer(const Duration(milliseconds: 180), () {
      if (!_overCard && !_overPreview && mounted && _portal.isShowing) _portal.hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: FocusableActionDetector(
        shortcuts: kActivateShortcuts,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onOpen();
            return null;
          }),
        },
        onShowFocusHighlight: (f) {
          if (f != _focused) setState(() => _focused = f);
          if (f) _ensureVisible();
        },
        child: MouseRegion(
          onEnter: (_) => _enter(),
          onExit: (_) => _exitCard(),
          child: GestureDetector(
            onTap: widget.onOpen,
            child: AnimatedScale(
              scale: _focused ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: KeyedSubtree(key: _key, child: widget.builder(_overCard || _focused)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext ctx) {
    const w = 430.0, h = 540.0;
    final screen = MediaQuery.of(ctx).size;
    double x = _rect.center.dx - w / 2;
    double y = _rect.center.dy - h / 2;
    x = x.clamp(8.0, (screen.width - w - 8).clamp(8.0, double.infinity));
    y = y.clamp(8.0, (screen.height - h - 8).clamp(8.0, double.infinity));
    return Stack(children: [
      Positioned(
        left: x, top: y,
        child: MouseRegion(
          onEnter: (_) { _overPreview = true; },
          onExit: (_) { _overPreview = false; _scheduleHide(); },
          child: MoviePreviewCard(
            movie: widget.movie,
            width: w,
            onOpen: () { _portal.hide(); widget.onOpen(); },
          ),
        ),
      ),
    ]);
  }
}

class MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;
  final double width;
  final int? rank; // nếu có: hiện số thứ tự VÀNG cạnh tên (dùng cho hàng "Top ...")
  const MovieCard({super.key, required this.movie, required this.onTap, this.width = 180, this.rank});

  @override
  Widget build(BuildContext context) {
    // TV (Android): KHÔNG dựng ô preview lớn — không có chuột để rê, mà lại
    // tốn bộ nhớ/hiệu năng. KHÔNG phóng to (scale 1.0) để không phá layout khi
    // chọn; báo focus bằng viền đỏ + quầng sáng + tên đổi màu đỏ trong _card.
    if (Platform.isAndroid) {
      return FocusHighlight(
        onPressed: onTap,
        scale: 1.0,
        builder: (f) => _card(f),
      );
    }
    return HoverPreview(
      movie: movie,
      onOpen: onTap,
      builder: (hovering) => _card(hovering),
    );
  }

  // Pill loại tiếng ở đáy poster (kiểu RoPhim): PĐ. (xanh ngọc) / TM. (xanh dương) / LT. (tím)
  Widget _langPill(String s, Color bg) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
      );

  List<Widget> _langPills(Movie m) => [
        if (m.hasPhuDe) _langPill('PĐ.', const Color(0xFF00A6A6)),
        if (m.hasThuyetMinh) _langPill('TM.', const Color(0xFF2962FF)),
        if (m.hasLongTieng) _langPill('LT.', const Color(0xFF7C4DFF)),
      ];

  /// Card kiểu RoPhim: poster dọc bo góc, pill loại tiếng ở ĐÁY poster; TÊN PHIM
  /// (Việt + tên gốc) và số tập nằm BÊN DƯỚI. Chọn/hover: viền đỏ + quầng sáng +
  /// tên đổi màu đỏ (KHÔNG phóng to trên TV để khỏi phá layout).
  Widget _card(bool hovering) {
    final m = movie;
    final img = m.thumbUrl.isNotEmpty ? m.thumbUrl : m.posterUrl;
    final pills = _langPills(m);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // Khung VÀNG GOLD khi chọn/hover + bóng đổ nổi khối (luôn có) + quầng vàng khi chọn.
            border: Border.all(color: hovering ? kAmber : Colors.white12, width: hovering ? 3 : 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 6)),
              if (hovering) BoxShadow(color: kAmber.withValues(alpha: 0.55), blurRadius: 22, spreadRadius: 1),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: img, fit: BoxFit.cover,
                memCacheWidth: 400, maxWidthDiskCache: 400,
                placeholder: (c, _) => Container(color: kSurface),
                errorWidget: (c, _, _) => Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.white24)),
              ),
              // Vệt tối ở đáy để badge/nhãn nổi rõ + tạo chiều sâu.
              Positioned(
                left: 0, right: 0, bottom: 0, height: 64,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent]),
                  ),
                ),
              ),
              if (pills.isNotEmpty)
                Positioned(left: 8, right: 8, bottom: 8, child: Row(children: pills)),
              // Chọn/hover: phủ tối nhẹ + nút play tròn hiện dần ở giữa.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: hovering ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kRed,
                          boxShadow: [BoxShadow(color: kRed.withValues(alpha: 0.6), blurRadius: 16)],
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (rank != null) ...[
            _rankNumber(rank!),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: hovering ? kAmber : Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              if (m.originalName.isNotEmpty)
                Text(m.originalName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              if (m.currentEpisode.isNotEmpty)
                Text(episodeLabel(m), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    ]);
  }

  // Số thứ tự VÀNG nghiêng, viền đen — đặt cạnh tên phim (dùng cho hàng Top).
  Widget _rankNumber(int n) {
    final s = '$n';
    return Stack(children: [
      Text(s,
          style: TextStyle(
            fontSize: 38, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.black,
          )),
      Text(s,
          style: const TextStyle(
            fontSize: 38, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.0, color: kAmber,
          )),
    ]);
  }
}

/// Ô preview lớn hiện khi hover: ảnh + tên + IMDb + thể loại + mô tả + nút.
class MoviePreviewCard extends ConsumerWidget {
  final Movie movie;
  final double width;
  final VoidCallback onOpen;
  const MoviePreviewCard({super.key, required this.movie, required this.width, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = movie.originalName.isNotEmpty ? movie.originalName : movie.name;
    // Dùng CÙNG ảnh với thẻ nhỏ (thumb ưu tiên) -> ảnh đã tải sẵn, hiện NGAY khi
    // rê chuột, không phải chờ tải ảnh poster khác vài giây.
    final img = movie.thumbUrl.isNotEmpty ? movie.thumbUrl : movie.posterUrl;
    final detail = ref.watch(detailProvider(movie.slug));
    final rating = ref.watch(tmdbRatingProvider(q));
    final store = ref.watch(storeProvider);
    final fav = store.isFavorite(movie.slug);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 24, spreadRadius: 2)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Bấm vào ảnh để mở phim
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: GestureDetector(
                    onTap: onOpen,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Stack(children: [
                        CachedNetworkImage(imageUrl: img, width: width, height: 250, fit: BoxFit.cover,
                            memCacheWidth: 500, maxWidthDiskCache: 500,
                            errorWidget: (c, _, _) => Container(width: width, height: 250, color: kSurface)),
                        Positioned.fill(
                          child: Container(decoration: const BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0xFF1B1B1B), Colors.transparent]))),
                        ),
                      ]),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(movie.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (movie.originalName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(movie.originalName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.amber, fontSize: 13)),
                ),
              const SizedBox(height: 10),
              Row(children: [
                ElevatedButton.icon(onPressed: onOpen, icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Xem ngay')),
                const SizedBox(width: 8),
                _iconBtn(fav ? Icons.favorite : Icons.favorite_border, () async {
                  final favMovie = detail.maybeWhen(
                    data: (d) => Movie.fromJson({
                      'name': d.name, 'slug': d.slug, 'poster_url': d.posterUrl, 'thumb_url': d.thumbUrl,
                      'quality': d.base.quality, 'current_episode': d.base.currentEpisode,
                      'total_episodes': d.base.totalEpisodes, 'genres': d.genres.map((g) => g.name).toList(),
                    }),
                    orElse: () => movie,
                  );
                  await store.toggleFavorite(favMovie);
                  ref.read(homeRefreshProvider.notifier).state++;
                }),
                const SizedBox(width: 8),
                _iconBtn(Icons.info_outline, onOpen),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                rating.maybeWhen(
                  data: (r) => r == null ? const SizedBox.shrink() : _imdb(r.rating),
                  orElse: () => const SizedBox.shrink(),
                ),
                detail.maybeWhen(
                  data: (d) => d.year != null ? _pill(d.year!) : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
                if (movie.currentEpisode.isNotEmpty) _pill(episodeLabel(movie)),
              ]),
              const SizedBox(height: 8),
              detail.maybeWhen(
                data: (d) => d.genres.isEmpty
                    ? const SizedBox.shrink()
                    : Text(d.genres.map((g) => g.name).join('  •  '),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                orElse: () => const SizedBox.shrink(),
              ),
              // Nội dung giới thiệu: cuộn được để hiện đủ, thẻ không dài vô tận.
              detail.maybeWhen(
                data: (d) => d.description.trim().isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              primary: false,
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(d.description,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                            ),
                          ),
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 40), padding: EdgeInsets.zero,
          side: const BorderSide(color: Colors.white54),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      );

  Widget _imdb(double r) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: Colors.amber), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('IMDb', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(r.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _pill(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(4)),
        child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );
}
