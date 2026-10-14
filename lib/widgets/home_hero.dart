import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../screens/detail_screen.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'movie_card.dart' show episodeLabel;
import 'tv_focusable.dart';

/// Băng "Phim nổi bật" đầu trang chủ (theo mẫu thiết kế 10/2026): ảnh ngang
/// lớn bên phải, chữ + nút bên trái, tự chuyển phim sau vài giây, có mũi tên và
/// chấm trang.
///
/// Remote TV: ▼ từ menu xuống là tới nút "Xem ngay". Đang ở "Xem ngay" bấm ◀ thì
/// lùi một phim, đang ở "Chi tiết" bấm ▶ thì sang phim kế (TV không hiện mũi
/// tên tròn: remote khó với tới, lại dễ trượt focus xuống hàng dưới).
///
/// ⚠️ Chiều cao CỐ ĐỊNH theo bề rộng màn, không theo ảnh. Bản hero cũ (bỏ ở
/// 7342451) bị nhảy layout mỗi khi phim thiếu ảnh ngang TMDB; giữ khung cố định
/// thì ảnh nào thiếu cũng chỉ đổi nội dung bên trong, các hàng dưới đứng yên.
class HomeHero extends ConsumerStatefulWidget {
  const HomeHero({super.key});
  @override
  ConsumerState<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<HomeHero> {
  int _i = 0;
  Timer? _timer;
  // Dừng tự chuyển khi chuột đang rê / remote đang chọn nút trong băng, để
  // phim không đổi ngay lúc người dùng sắp bấm.
  bool _hold = false;
  final _playNode = FocusNode(debugLabel: 'hero-play');
  final _detailNode = FocusNode(debugLabel: 'hero-detail');

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      // Đang xem phim / mở trang khác (trang chủ vẫn sống phía dưới) thì thôi
      // đổi ảnh: tránh tải + vẽ ảnh lớn ngầm, nhất là trên TV box yếu.
      if (_hold || !mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      // Đã cuộn xuống các hàng dưới (băng khuất) thì cũng thôi: đổi ảnh lớn ngay
      // lúc đang bấm remote ở hàng dưới làm khựng trên box yếu.
      final pos = Scrollable.maybeOf(context)?.position;
      if (pos != null && pos.pixels > 120) return;
      _step(1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playNode.dispose();
    _detailNode.dispose();
    super.dispose();
  }

  int _count = 0;
  void _step(int d) {
    if (_count < 2) return;
    setState(() => _i = (_i + d) % _count);
  }

  /// ◀ ở nút đầu / ▶ ở nút cuối = đổi phim, focus vẫn đứng nguyên trên nút.
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft && _playNode.hasFocus) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight && _detailNode.hasFocus) {
      _step(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _open(Movie m, {bool play = false}) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailScreen(slug: m.slug, title: m.name, autoPlay: play)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(featuredMoviesProvider);
    return LayoutBuilder(builder: (context, cons) {
      final h = (cons.maxWidth * 0.36).clamp(320.0, 520.0);
      final infoW = (cons.maxWidth * 0.5).clamp(420.0, 640.0);
      return async.when(
        loading: () => SizedBox(height: h, child: Container(color: Colors.white.withValues(alpha: 0.03))),
        // Lỗi mạng: bỏ hẳn băng, các hàng dưới vẫn có nút thử lại của riêng chúng.
        error: (_, _) => const SizedBox.shrink(),
        data: (list) {
          if (list.isEmpty) return const SizedBox.shrink();
          _count = list.length;
          if (_i >= list.length) _i = 0;
          final m = list[_i];
          return Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (f) => _hold = f,
            child: MouseRegion(
              onEnter: (_) => _hold = true,
              onExit: (_) => _hold = false,
              child: SizedBox(
                height: h,
                child: Stack(fit: StackFit.expand, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: _Backdrop(key: ValueKey(m.slug), movie: m),
                  ),
                  Positioned(
                    left: 50, top: 24, bottom: 40,
                    width: infoW,
                    // Băng thấp (TV 960 điểm, cửa sổ nhỏ) thì THU NHỎ cả khối chữ
                    // thay vì tràn: tên 2 dòng + mô tả + nút cao ~320 điểm.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: infoW,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            layoutBuilder: (cur, prev) => Stack(
                                alignment: Alignment.bottomLeft, children: [...prev, ?cur]),
                            child: _Info(key: ValueKey(m.slug), movie: m),
                          ),
                          const SizedBox(height: 20),
                          // ⚠️ Nút nằm NGOÀI AnimatedSwitcher: đổi phim mà dựng lại
                          // nút thì nút đang được remote chọn bị huỷ -> mất focus.
                          Focus(
                            canRequestFocus: false,
                            skipTraversal: true,
                            onKeyEvent: _onKey,
                            child: Row(children: [
                              _HeroButton(
                                  focusNode: _playNode, primary: true, icon: Icons.play_arrow_rounded,
                                  label: 'Xem ngay', onTap: () => _open(m, play: true)),
                              const SizedBox(width: 14),
                              _HeroButton(
                                  focusNode: _detailNode, primary: false, icon: Icons.info_outline,
                                  label: 'Chi tiết', onTap: () => _open(m)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  if (list.length > 1) ...[
                    if (!Platform.isAndroid)
                    Positioned(
                      right: 34, top: 0, bottom: 0,
                      child: Center(
                        child: Row(children: [
                          _Arrow(icon: Icons.chevron_left, onTap: () => _step(-1)),
                          const SizedBox(width: 14),
                          _Arrow(icon: Icons.chevron_right, onTap: () => _step(1)),
                        ]),
                      ),
                    ),
                    Positioned(
                      left: 0, right: 0, bottom: 14,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (int k = 0; k < list.length; k++)
                          GestureDetector(
                            onTap: () => setState(() => _i = k),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: k == _i ? 22 : 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: k == _i ? kRed : Colors.white38,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        // TV: nhắc cách đổi phim bằng remote (không có mũi tên tròn).
                        if (Platform.isAndroid)
                          const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Text('◀ ▶ đổi phim', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
          );
        },
      );
    });
  }
}

/// Ảnh ngang phủ kín, mờ dần sang trái (chỗ đặt chữ) và xuống dưới (hoà vào nền).
class _Backdrop extends ConsumerWidget {
  final Movie movie;
  const _Backdrop({super.key, required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = movie.originalName.isNotEmpty ? movie.originalName : movie.name;
    final tmdb = ref.watch(backdropProvider(q)).maybeWhen(data: (u) => u, orElse: () => null);
    final img = (tmdb != null && tmdb.isNotEmpty) ? tmdb : movie.wideUrl;
    return Stack(fit: StackFit.expand, children: [
      if (img.isNotEmpty)
        CachedNetworkImage(
          imageUrl: img, fit: BoxFit.cover, alignment: Alignment.topCenter,
          memCacheWidth: 1280, maxWidthDiskCache: 1280,
          fadeInDuration: const Duration(milliseconds: 250),
          placeholder: (c, _) => const SizedBox.shrink(),
          errorWidget: (c, _, _) => const SizedBox.shrink(),
        ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [Color(0xF00E0D16), Color(0x990E0D16), Colors.transparent],
            stops: [0.0, 0.38, 0.7],
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Color(0xFF0E0D16), Colors.transparent],
            stops: [0.0, 0.35],
          ),
        ),
      ),
    ]);
  }
}

class _Info extends ConsumerWidget {
  final Movie movie;
  const _Info({super.key, required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Danh sách từ nguồn không có mô tả/thể loại/năm -> lấy thêm từ chi tiết.
    final d = ref.watch(detailProvider(movie.slug)).maybeWhen(data: (d) => d, orElse: () => null);
    final year = d?.year ?? movie.year;
    final ep = episodeLabel(movie);
    final genres = d?.genres.take(2).map((g) => g.name).toList() ?? const <String>[];
    final desc = (d?.description ?? movie.description).replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final meta = <Widget>[
      if (year.isNotEmpty) _metaText(year, icon: Icons.schedule),
      if (ep.isNotEmpty) _metaText(ep),
      if (movie.quality.isNotEmpty) _qualityBox(movie.quality),
      for (final g in genres) _metaText(g),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kRed.withValues(alpha: 0.6)),
        ),
        child: const Text('Phim nổi bật',
            style: TextStyle(color: Color(0xFFFF6B7D), fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 12),
      // Tên phim to, dải trắng -> hồng đỏ cho giống chữ tiêu đề trong mẫu.
      // ⚠️ Bóng chữ phải nằm ở lớp RIÊNG bên dưới: để shadows trong ShaderMask
      // thì bóng cũng bị tô dải màu, hiện thành ô chữ nhật mờ sau từng chữ.
      Stack(children: [
        Text(movie.name, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: _title.copyWith(
              color: Colors.transparent,
              shadows: const [Shadow(color: Colors.black, blurRadius: 18, offset: Offset(0, 3))],
            )),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFF8FA0), kRedHot],
            stops: [0.0, 0.6, 1.0],
          ).createShader(r),
          child: Text(movie.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _title),
        ),
      ]),
      if (movie.originalName.isNotEmpty && movie.originalName != movie.name)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(movie.originalName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 15)),
        ),
      const SizedBox(height: 14),
      if (meta.isNotEmpty)
        Wrap(spacing: 0, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (int i = 0; i < meta.length; i++) ...[
            if (i > 0) const Text('   •   ', style: TextStyle(color: Colors.white38, fontSize: 13)),
            meta[i],
          ],
        ]),
      if (desc.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
      ],
    ]);
  }

  static const _title = TextStyle(fontFamily: kBrandFont, fontSize: 44, fontWeight: FontWeight.w700, height: 1.12);

  Widget _metaText(String s, {IconData? icon}) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(width: 5),
        ],
        Text(s, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
      ]);

  Widget _qualityBox(String q) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.white70),
        ),
        child: Text(q, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

/// Nút viên thuốc: "Xem ngay" đỏ dải màu, "Chi tiết" tối trong suốt. Remote
/// chọn tới thì viền trắng + quầng sáng.
class _HeroButton extends StatelessWidget {
  final bool primary;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final FocusNode focusNode;
  const _HeroButton({required this.focusNode, required this.primary, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => FocusHighlight(
        focusNode: focusNode,
        onPressed: onTap,
        scale: 1.05,
        builder: (f) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            gradient: primary ? kRedGradient : null,
            color: primary ? null : Colors.white.withValues(alpha: f ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: f ? Colors.white : (primary ? Colors.transparent : Colors.white30), width: 2),
            boxShadow: [
              if (primary) BoxShadow(color: kRed.withValues(alpha: f ? 0.8 : 0.45), blurRadius: f ? 22 : 14),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Arrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => FocusHighlight(
        onPressed: onTap,
        scale: 1.0,
        builder: (f) => Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: f ? 0.75 : 0.45),
            border: Border.all(color: f ? kRed : Colors.white24, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      );
}
