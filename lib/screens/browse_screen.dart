import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../data/movie_source.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_row.dart';
import '../widgets/multi_filter_bar.dart';
import '../widgets/lang_filter_row.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/async_view.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';

/// Màn "Thư viện phim" (gộp cả Tìm kiếm cũ): phần đầu + ô tìm to + tìm kiếm phổ
/// biến + gần đây/xu hướng + bộ lọc + loại tiếng + lưới (mẫu thiết kế 10/2026).
/// Tối ưu remote TV: ô tìm là NÚT (bấm OK mới mở bàn phím) nên con trỏ KHÔNG bị
/// hút vào ô gõ; bộ lọc là nút bấm (không phải dropdown) nên D-pad đi dọc mượt.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});
  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  BrowseFilter _filter = const BrowseFilter();
  String _keyword = '';
  final Set<String> _langs = {}; // rỗng = mọi loại; phude/thuyetminh/longtieng (chọn nhiều)
  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  final _searchBtnFocus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;

  /// Giu san notifier cua co "dang go". Trong dispose() KHONG duoc dung `ref`
  /// nua, nen phai bat san tu initState.
  late final StateController<bool> _typingCtl;

  @override
  void initState() {
    super.initState();
    _typingCtl = ref.read(searchTypingProvider.notifier);
    // Mở từ ô tìm trên thanh menu: cờ "đang gõ" đã bật TRƯỚC khi màn này dựng
    // nên ref.listen bên dưới không bắt được -> tự đưa con trỏ vào ô gõ ở đây.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(searchTypingProvider)) _fieldFocus.requestFocus();
    });
    _scroll.addListener(() {
      // Cả trang giờ chung một thanh cuộn: chỉ tải thêm khi đang xem lưới LỌC
      // (trang gợi ý / kết quả tìm không có trang sau).
      final browsing = !_filter.isEmpty || _langs.isNotEmpty;
      if (browsing && _keyword.trim().length < 2 && _scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(filterBrowseProvider(_filter).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _fieldFocus.dispose();
    _searchBtnFocus.dispose();
    _scroll.dispose();
    // Roi man -> xoa co dang go de Shell khong hieu nham.
    // KHONG dung Future.microtask + ref: microtask chay SAU khi dispose xong nen
    // `ref` da chet -> nem StateError va co KHONG BAO GIO duoc xoa (Shell tuong
    // van dang go, bam Back o Trang chu khong thoat duoc app). Dung notifier da
    // bat san tu initState thi khong phu thuoc widget con song hay khong.
    _typingCtl.state = false;
    super.dispose();
  }

  // Chờ gõ xong 0.25s mới tìm -> tránh bắn request liên tục theo từng phím.
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _keyword = v);
    });
  }

  void _startTyping() => ref.read(searchTypingProvider.notifier).state = true;
  void _stopTyping() => ref.read(searchTypingProvider.notifier).state = false;

  // Lọc theo loại tiếng (phía app). Chọn nhiều -> khớp 1 trong các loại đã chọn.
  List<Movie> _applyLang(List<Movie> items) {
    if (_langs.isEmpty) return items;
    return items.where((m) =>
        (_langs.contains('phude') && m.hasPhuDe) ||
        (_langs.contains('thuyetminh') && m.hasThuyetMinh) ||
        (_langs.contains('longtieng') && m.hasLongTieng)).toList();
  }

  void _open(Movie m) {
    // Mở phim từ kết quả tìm = từ khoá đó dùng được -> nhớ vào "Tìm kiếm gần đây".
    if (_keyword.trim().length >= 2) ref.read(storeProvider).addRecentSearch(_keyword);
    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name)));
  }

  void _browse(String title, BrowseQuery query) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => CategoryListScreen(title: title, query: query)));

  @override
  Widget build(BuildContext context) {
    // Khi cờ "đang gõ" tắt (do bấm Back/Xong) -> bỏ focus ô gõ, trả con trỏ về
    // nút Tìm để đi tiếp bằng remote. Khi bật -> đưa con trỏ vào ô gõ.
    ref.listen(searchTypingProvider, (prev, typing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (typing) {
          _fieldFocus.requestFocus();
        } else {
          _fieldFocus.unfocus();
          _searchBtnFocus.requestFocus();
        }
      });
    });

    final searching = _keyword.trim().length >= 2;
    // Chọn LOẠI TIẾNG cũng tính là đang duyệt -> chuyển sang lưới có cuộn-tải-thêm.
    // Trước đây chỉ bộ lọc Loại/Thể loại/Quốc gia/Năm mới chuyển, còn lọc tiếng
    // thì vẫn hiện 2 hàng gợi ý và lọc trên đúng 20 phim đã tải -> chọn "Thuyết
    // minh" xong chỉ còn 3 phim, trông như nguồn chỉ có 3 phim. Lưới thì gom
    // nhiều trang (BrowseNotifier tải 3 trang/lượt) nên lọc ra đủ phim.
    final browsing = !_filter.isEmpty || _langs.isNotEmpty;

    // Bố cục theo mẫu thiết kế 10/2026: CẢ TRANG CUỘN LIỀN (phần đầu + ô tìm +
    // gợi ý + bộ lọc + kết quả). Trước đây khối tìm/lọc đứng yên ở trên nên phải
    // nén còn ~110px cho vừa màn 1080p; giờ nó cuộn đi cùng trang nên làm to,
    // dễ nhìn được — remote ▼ tự đưa hàng đang chọn ra giữa (tvRequestFocus).
    return FocusTraversalGroup(
      policy: tvFocusPolicy,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(child: _hero()),
          if (!searching && !browsing) SliverToBoxAdapter(child: _recentAndTrending()),
          SliverToBoxAdapter(child: _filterPanel()),
          ...(searching
              ? _searchResults()
              : browsing
                  ? _browseBody()
                  : _suggestHub()),
          SliverToBoxAdapter(child: SizedBox(height: Platform.isAndroid ? 44 : 24)),
        ],
      ),
    );
  }

  /// Lề ngang chung của trang (TV rộng hơn vì bị cắt mép).
  double get _edge => Platform.isAndroid ? 28 : 24;

  // ---------- Phần đầu: tiêu đề + ô tìm + tìm kiếm phổ biến ----------

  Widget _hero() {
    return LayoutBuilder(builder: (context, cons) {
      final wide = cons.maxWidth >= 1000;
      final title = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('KHÁM PHÁ THẾ GIỚI',
            style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 6, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text('Phim ảnh không giới hạn',
            style: TextStyle(
              color: Colors.white, fontSize: wide ? 44 : 34, fontWeight: FontWeight.w700, height: 1.15,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 16)],
            )),
        const SizedBox(height: 10),
        const Text('Tìm kiếm hàng ngàn bộ phim, series yêu thích trên VieFlix',
            style: TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.5)),
      ]);
      final search = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _searchArea(),
        const SizedBox(height: 16),
        const Text('Tìm kiếm phổ biến', style: TextStyle(color: Colors.white70, fontSize: 13.5)),
        const SizedBox(height: 10),
        _popularChips(),
      ]);
      return Padding(
        padding: EdgeInsets.fromLTRB(_edge, wide ? 36 : 24, _edge, 20),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 5, child: title),
                const SizedBox(width: 40),
                Expanded(flex: 7, child: search),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                title,
                const SizedBox(height: 20),
                search,
              ]),
      );
    });
  }

  /// Lối tắt bộ lọc hay dùng. Bấm = thay toàn bộ bộ lọc bằng một chiều này.
  static const _popular = [
    (Icons.local_fire_department, 'Phim Trung Quốc', BrowseFilter(country: 'trung-quoc')),
    (Icons.favorite, 'Phim Hàn Quốc', BrowseFilter(country: 'han-quoc')),
    (Icons.castle, 'Cổ trang', BrowseFilter(genre: 'co-trang')),
    (Icons.favorite_border, 'Tình cảm', BrowseFilter(genre: 'tinh-cam')),
    (Icons.smart_toy, 'Hoạt hình', BrowseFilter(type: 'hoat-hinh')),
    (Icons.sports_martial_arts, 'Hành động', BrowseFilter(genre: 'hanh-dong')),
    (Icons.sentiment_very_satisfied, 'Hài hước', BrowseFilter(genre: 'hai')),
    (Icons.nights_stay, 'Kinh dị', BrowseFilter(genre: 'kinh-di')),
  ];

  Widget _popularChips() => Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (icon, label, f) in _popular)
          _pill(
            icon: icon,
            label: label,
            selected: _filter == f,
            onTap: () => setState(() {
              _filter = _filter == f ? const BrowseFilter() : f;
              _keyword = '';
              _controller.clear();
            }),
          ),
      ]);

  /// Viên thuốc bấm được (gợi ý / lịch sử). Chọn: nền đỏ dải màu.
  Widget _pill({
    IconData? icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
  }) =>
      FocusHighlight(
        scale: 1.0,
        onPressed: onTap,
        builder: (f) => Container(
          padding: EdgeInsets.fromLTRB(14, 8, trailing != null ? 8 : 16, 8),
          decoration: BoxDecoration(
            gradient: selected ? kRedGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: f ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: f ? Colors.white : (selected ? Colors.transparent : Colors.white24), width: f ? 2 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.white70),
              const SizedBox(width: 7),
            ],
            Text(label,
                style: TextStyle(
                    color: Colors.white, fontSize: 13.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            if (trailing != null) ...[const SizedBox(width: 6), trailing],
          ]),
        ),
      );

  // ---------- Tìm gần đây + xu hướng ----------

  Widget _recentAndTrending() {
    final recent = ref.watch(storeProvider).recentSearches;
    final trending =
        ref.watch(topSeriesProvider).maybeWhen(data: (l) => l.take(6).toList(), orElse: () => <Movie>[]);
    final recentPanel = _panel(
      icon: Icons.history,
      title: 'Tìm kiếm gần đây',
      action: recent.isEmpty
          ? null
          : FocusHighlight(
              scale: 1.0,
              onPressed: () async {
                await ref.read(storeProvider).clearRecentSearches();
                if (mounted) setState(() {});
              },
              builder: (f) => Text('Xoá hết',
                  style: TextStyle(color: f ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
      child: recent.isEmpty
          ? const Text('Chưa tìm gì. Từ khoá bạn tìm sẽ hiện ở đây.',
              style: TextStyle(color: Colors.white38, fontSize: 13))
          : Wrap(spacing: 10, runSpacing: 10, children: [
              for (final k in recent)
                _pill(
                  icon: Icons.search,
                  label: k,
                  selected: false,
                  onTap: () => _searchFor(k),
                  // ✕ chỉ cho chuột; TV dùng "Xoá hết" (remote không trỏ được nút nhỏ).
                  trailing: Platform.isAndroid
                      ? null
                      : GestureDetector(
                          onTap: () async {
                            await ref.read(storeProvider).removeRecentSearch(k);
                            if (mounted) setState(() {});
                          },
                          child: const Icon(Icons.close, size: 16, color: Colors.white54),
                        ),
                ),
            ]),
    );
    final trendPanel = trending.isEmpty
        ? null
        : _panel(
            icon: Icons.trending_up,
            title: 'Xu hướng hôm nay',
            action: FocusHighlight(
              scale: 1.0,
              onPressed: () => _browse('Phim Bộ', const BrowseQuery('type', 'phim-bo')),
              builder: (f) => Text('Xem tất cả  ›',
                  style: TextStyle(color: f ? Colors.white : kRed, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            child: LayoutBuilder(builder: (context, cons) {
              final cols = cons.maxWidth >= 420 ? 2 : 1;
              final w = (cons.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(spacing: 16, runSpacing: 2, children: [
                for (int i = 0; i < trending.length; i++) SizedBox(width: w, child: _trendItem(i + 1, trending[i])),
              ]);
            }),
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(_edge, 0, _edge, 16),
      child: LayoutBuilder(builder: (context, cons) {
        if (trendPanel == null) return recentPanel;
        if (cons.maxWidth < 900) {
          return Column(children: [recentPanel, const SizedBox(height: 14), trendPanel]);
        }
        // ⚠️ KHÔNG bọc IntrinsicHeight để hai ô cao bằng nhau: ô Xu hướng dùng
        // LayoutBuilder (chia 2 cột theo bề ngang), mà LayoutBuilder không trả
        // được kích thước "intrinsic" -> lỗi khi vẽ, cả trang Thư viện trống trơn.
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: recentPanel),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: trendPanel),
        ]);
      }),
    );
  }

  Widget _trendItem(int rank, Movie m) => FocusHighlight(
        scale: 1.0,
        onPressed: () => _open(m),
        builder: (f) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: f ? Colors.white12 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: f ? kRed : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            SizedBox(
              width: 22,
              child: Text('$rank',
                  style: TextStyle(color: rank <= 3 ? kAmber : Colors.white54, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(m.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
            ),
          ]),
        ),
      );

  /// Khung bo góc nền tối mờ có tiêu đề + icon (ô "gần đây", "xu hướng").
  Widget _panel({required IconData icon, required String title, Widget? action, required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(icon, size: 20, color: Colors.white70),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ?action,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  /// Gõ sẵn [k] vào ô tìm và tìm luôn (bấm mục "Tìm kiếm gần đây").
  void _searchFor(String k) {
    _debounce?.cancel();
    _controller.text = k;
    setState(() {
      _keyword = k;
      _filter = const BrowseFilter();
      _langs.clear();
    });
  }

  // ---------- Bộ lọc ----------

  Widget _filterPanel() => Padding(
        padding: EdgeInsets.fromLTRB(_edge, 0, _edge, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.tune, size: 19, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('Bộ lọc', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              Expanded(
                child: MultiFilterBar(
                  current: _filter,
                  onChanged: (f) => setState(() {
                    _filter = f;
                    // Chọn bộ lọc -> chuyển sang chế độ duyệt: xoá từ khoá đang tìm.
                    _keyword = '';
                    _controller.clear();
                  }),
                ),
              ),
            ]),
            LangFilterRow(
              padding: const EdgeInsets.only(top: 6),
              selected: _langs,
              onChanged: (s) => setState(() {
                _langs
                  ..clear()
                  ..addAll(s);
              }),
            ),
          ]),
        ),
      );

  // ---------- Ô tìm ----------

  Widget _searchArea() {
    // PC: gõ trực tiếp (KHÔNG autofocus để không "hút" con trỏ khi vào màn).
    if (!Platform.isAndroid) return _searchBox(child: _field(tv: false));
    // TV: nút mở bàn phím <-> ô gõ (theo cờ đang gõ).
    final typing = ref.watch(searchTypingProvider);
    return typing ? _searchBox(child: _field(tv: true)) : _tvSearchButton();
  }

  /// Khung ô tìm to theo mẫu: nền tối mờ, viền đỏ phát sáng (sáng hơn khi đang
  /// gõ / được remote chọn).
  Widget _searchBox({required Widget child, bool lit = false}) => AnimatedBuilder(
        animation: _fieldFocus,
        builder: (context, _) {
          final on = lit || _fieldFocus.hasFocus;
          return Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: kRed.withValues(alpha: on ? 1 : 0.6), width: on ? 2 : 1.5),
              boxShadow: [BoxShadow(color: kRed.withValues(alpha: on ? 0.55 : 0.25), blurRadius: on ? 24 : 16)],
            ),
            child: child,
          );
        },
      );

  Widget _field({required bool tv}) => TextField(
        controller: _controller,
        focusNode: _fieldFocus,
        autofocus: tv,
        cursorColor: kRed,
        style: const TextStyle(color: Colors.white, fontSize: 17),
        textInputAction: TextInputAction.search,
        onChanged: (v) {
          _onChanged(v);
          if (!tv) setState(() {}); // hiện/ẩn nút xoá chữ
        },
        onSubmitted: (v) {
          ref.read(storeProvider).addRecentSearch(v);
          if (tv) _stopTyping();
        },
        onTapOutside: tv ? (_) => _stopTyping() : null,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: tv ? 'Gõ tên phim (có thể gõ KHÔNG DẤU)…' : 'Tìm phim, series… (gõ không dấu cũng được)',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 16),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.search, color: Colors.white70, size: 26),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          // TV: nút "xong" để đóng bàn phím, quay ra điều hướng bằng remote.
          // PC: nút xoá chữ khi đã gõ.
          suffixIcon: tv
              ? IconButton(
                  tooltip: 'Xong',
                  icon: const Icon(Icons.keyboard_hide, color: Colors.white54),
                  onPressed: _stopTyping,
                )
              : (_controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xoá',
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => setState(() {
                        _debounce?.cancel();
                        _controller.clear();
                        _keyword = '';
                      }),
                    )),
        ),
      );

  Widget _tvSearchButton() => FocusHighlight(
        focusNode: _searchBtnFocus,
        autofocus: true, // vào màn: con trỏ đậu ở NÚT tìm, không phải ô text
        scale: 1.0,
        onPressed: _startTyping,
        builder: (f) => _searchBox(
          lit: f,
          child: Row(children: [
            const Icon(Icons.search, color: Colors.white70, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _keyword.isEmpty ? 'Bấm OK để gõ tên phim…' : _keyword,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _keyword.isEmpty ? Colors.white38 : Colors.white, fontSize: 17),
              ),
            ),
            if (_keyword.isNotEmpty) const Icon(Icons.edit, color: Colors.white38, size: 18),
          ]),
        ),
      );

  // ---------- Nội dung ----------

  /// Tiêu đề khối kết quả: vạch đỏ + tên + dòng phụ đỏ.
  Widget _resultsHeader(String title, String? sub) => SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(_edge, 14, _edge, 10),
          child: Row(children: [
            Container(
                width: 4, height: 22, decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            if (sub != null) ...[
              const SizedBox(width: 14),
              Flexible(
                child: Text(sub,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kRedHot, fontSize: 13.5)),
              ),
            ],
          ]),
        ),
      );

  Widget _grid(List<Movie> items) => SliverPadding(
        // TV cắt mép (overscan) nên chừa lề ngang rộng hơn hẳn so với PC.
        padding: EdgeInsets.symmetric(horizontal: _edge - 6),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 14),
          delegate: SliverChildBuilderDelegate(
            (c, i) => MovieCard(movie: items[i], onTap: () => _open(items[i])),
            childCount: items.length,
          ),
        ),
      );

  Widget _box(Widget child) => SliverToBoxAdapter(
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: child),
      );

  List<Widget> _searchResults() {
    final kw = _keyword.trim();
    return ref.watch(searchProvider(_keyword)).when(
          data: (list) {
            final f = _applyLang(list);
            return [
              _resultsHeader('Kết quả tìm kiếm', 'Có ${f.length} kết quả cho “$kw”'),
              if (f.isEmpty)
                _box(const Center(child: Text('Không tìm thấy phim', style: TextStyle(color: Colors.white38))))
              else
                _grid(f),
            ];
          },
          loading: () => [
            _resultsHeader('Kết quả tìm kiếm', 'Đang tìm “$kw”…'),
            _box(const Center(child: CircularProgressIndicator(color: kRed))),
          ],
          error: (e, st) => [
            _resultsHeader('Kết quả tìm kiếm', null),
            _box(SizedBox(
              height: 160,
              child: AsyncView<void>(
                value: AsyncValue<void>.error(e, st),
                onRetry: () => ref.invalidate(searchProvider(_keyword)),
                builder: (_) => const SizedBox.shrink(),
              ),
            )),
          ],
        );
  }

  List<Widget> _browseBody() {
    final st = ref.watch(filterBrowseProvider(_filter));
    // Lưới chưa đủ dài để cuộn thì tự tải thêm trang (không có cú cuộn nào để
    // kích bộ nghe của _scroll).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (st.page < st.totalPage && !st.loading && _scroll.hasClients &&
          _scroll.position.maxScrollExtent - _scroll.position.pixels < 400) {
        ref.read(filterBrowseProvider(_filter).notifier).loadMore();
      }
    });
    final items = _applyLang(st.items);
    return [
      _resultsHeader('Kết quả lọc', items.isEmpty ? null : '${items.length}${st.page < st.totalPage ? '+' : ''} phim'),
      if (items.isEmpty && st.loading)
        _box(const Center(child: CircularProgressIndicator(color: kRed)))
      else if (items.isEmpty)
        _box(const Center(child: Text('Không có phim khớp bộ lọc', style: TextStyle(color: Colors.white38))))
      else
        _grid(items),
      if (st.loading && items.isNotEmpty)
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: kRed))),
        ),
    ];
  }

  // Chưa gõ + chưa lọc: hàng gợi ý phim cho đỡ trống.
  List<Widget> _suggestHub() => [
        SliverToBoxAdapter(
          child: _suggestRow('Thịnh hành', Icons.local_fire_department, topSeriesProvider,
              () => _browse('Phim Bộ', const BrowseQuery('type', 'phim-bo'))),
        ),
        SliverToBoxAdapter(
          child: _suggestRow('Mới cập nhật', Icons.auto_awesome, latestListProvider,
              () => _browse('Phim mới cập nhật', const BrowseQuery('all', ''))),
        ),
      ];

  Widget _suggestRow(String title, IconData icon, FutureProvider<List<Movie>> provider, VoidCallback onSeeMore) {
    return ref.watch(provider).maybeWhen(
          data: (list) {
            final f = _applyLang(list);
            return f.isEmpty
                ? const SizedBox.shrink()
                : MovieRow(
                    title: title,
                    icon: icon,
                    movies: f.take(20).toList(),
                    onTap: _open,
                    onSeeMore: onSeeMore,
                  );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}
