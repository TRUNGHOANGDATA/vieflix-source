import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_row.dart';
import '../widgets/tv_filter_bar.dart';
import '../widgets/lang_filter_row.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/async_view.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';

/// Màn "Thư viện phim" (gộp cả Tìm kiếm cũ): ô tìm + bộ lọc + loại tiếng + lưới.
/// Tối ưu remote TV: ô tìm là NÚT (bấm OK mới mở bàn phím) nên con trỏ KHÔNG bị
/// hút vào ô gõ; bộ lọc là nút bấm (không phải dropdown) nên D-pad đi dọc mượt.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});
  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  BrowseQuery _q = const BrowseQuery('all', '');
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
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(browseProvider(_q).notifier).loadMore();
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

  void _open(Movie m) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name)));

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
    final browsing = _q.kind != 'all';

    return FocusTraversalGroup(
      child: Column(children: [
        // Ô TÌM + 4 Ô LỌC CHUNG MỘT HÀNG. Trước đây mỗi thứ một hàng riêng, cộng
        // hàng loại tiếng nữa thì khối lọc ăn ~180px, mà màn 1080p chỉ còn ~890px
        // cho nội dung -> hàng phim bị đẩy xuống và cắt mất nửa dưới (thấy rõ
        // nhất trên TV vì TV còn cắt mép).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Row(children: [
            Expanded(flex: 4, child: _searchArea()),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: TvFilterBar(
                padding: EdgeInsets.zero,
                current: _q,
                onChanged: (q) => setState(() {
                  _q = q;
                  // Chọn bộ lọc -> chuyển sang chế độ duyệt: xoá từ khoá đang tìm.
                  _keyword = '';
                  _controller.clear();
                }),
              ),
            ),
          ]),
        ),
        LangFilterRow(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          selected: _langs,
          onChanged: (s) => setState(() {
            _langs
              ..clear()
              ..addAll(s);
          }),
        ),
        Expanded(
          child: searching
              ? _searchResults()
              : browsing
                  ? _browseBody()
                  : _suggestHub(),
        ),
      ]),
    );
  }

  // ---------- Ô tìm ----------

  Widget _searchArea() {
    // PC: gõ trực tiếp (KHÔNG autofocus để không "hút" con trỏ khi vào màn).
    if (!Platform.isAndroid) return _desktopField();
    // TV: nút mở bàn phím <-> ô gõ (theo cờ đang gõ).
    final typing = ref.watch(searchTypingProvider);
    return typing ? _tvField() : _tvSearchButton();
  }

  Widget _desktopField() => TextField(
        controller: _controller,
        focusNode: _fieldFocus,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: _fieldDecoration('Tìm phim theo tên...'),
        onChanged: _onChanged,
      );

  Widget _tvSearchButton() => FocusHighlight(
        focusNode: _searchBtnFocus,
        autofocus: true, // vào màn: con trỏ đậu ở NÚT tìm, không phải ô text
        scale: 1.0,
        onPressed: _startTyping,
        builder: (f) => Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: f ? kRed : Colors.white12, width: f ? 2 : 1.5),
            boxShadow: f ? [BoxShadow(color: kRed.withValues(alpha: 0.4), blurRadius: 14)] : null,
          ),
          child: Row(children: [
            const Icon(Icons.search, color: Colors.white54, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _keyword.isEmpty ? 'Bấm để gõ tên phim…' : _keyword,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _keyword.isEmpty ? Colors.white38 : Colors.white, fontSize: 16),
              ),
            ),
            if (_keyword.isNotEmpty)
              const Icon(Icons.edit, color: Colors.white38, size: 18),
          ]),
        ),
      );

  Widget _tvField() => TextField(
        controller: _controller,
        focusNode: _fieldFocus,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _stopTyping(),
        onTapOutside: (_) => _stopTyping(),
        decoration: _fieldDecoration('Gõ tên phim (có thể gõ KHÔNG DẤU)…').copyWith(
          // Nút "xong" để đóng bàn phím và quay ra điều hướng bằng remote.
          suffixIcon: IconButton(
            tooltip: 'Xong',
            icon: const Icon(Icons.keyboard_hide, color: Colors.white54),
            onPressed: _stopTyping,
          ),
        ),
        onChanged: _onChanged,
      );

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 22),
        filled: true,
        fillColor: kSurface,
        // 10 chu khong phai 16: o tim cao ~60px la qua nhieu cho mot man chi co
        // ~890px chieu cao noi dung.
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.white12, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: kRed, width: 2)),
      );

  // ---------- Nội dung ----------

  Widget _grid(List<Movie> items) => GridView.builder(
        controller: _scroll,
        // TV cat mep (overscan) nen hang cuoi bi mat mot phan neu sat vien ->
        // chua le duoi/ngang rong hon han so voi PC.
        padding: Platform.isAndroid
            ? const EdgeInsets.fromLTRB(28, 8, 28, 40)
            : const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: items.length,
        itemBuilder: (c, i) => MovieCard(movie: items[i], onTap: () => _open(items[i])),
      );

  Widget _searchResults() => AsyncView(
        value: ref.watch(searchProvider(_keyword)),
        onRetry: () => ref.invalidate(searchProvider(_keyword)),
        builder: (list) {
          final f = _applyLang(list);
          return f.isEmpty
              ? const Center(child: Text('Không tìm thấy phim', style: TextStyle(color: Colors.white38)))
              : _grid(f);
        },
      );

  Widget _browseBody() {
    final st = ref.watch(browseProvider(_q));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (st.page < st.totalPage && !st.loading && _scroll.hasClients &&
          _scroll.position.maxScrollExtent < 400) {
        ref.read(browseProvider(_q).notifier).loadMore();
      }
    });
    final items = _applyLang(st.items);
    if (items.isEmpty && st.loading) {
      return const Center(child: CircularProgressIndicator(color: kRed));
    }
    return Column(children: [
      Expanded(child: _grid(items)),
      if (st.loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: kRed)),
    ]);
  }

  // Chưa gõ + chưa lọc: hàng gợi ý phim cho đỡ trống.
  Widget _suggestHub() => FocusTraversalGroup(
        child: ListView(
            padding: EdgeInsets.only(top: 2, bottom: Platform.isAndroid ? 44 : 24),
            children: [
          _suggestRow('🔥 Thịnh hành', topSeriesProvider,
              () => _browse('Phim Bộ', const BrowseQuery('type', 'phim-bo'))),
          _suggestRow('🆕 Mới cập nhật', latestListProvider,
              () => _browse('Phim mới cập nhật', const BrowseQuery('all', ''))),
        ]),
      );

  Widget _suggestRow(String title, FutureProvider<List<Movie>> provider, VoidCallback onSeeMore) {
    return ref.watch(provider).maybeWhen(
          data: (list) {
            final f = _applyLang(list);
            return f.isEmpty
                ? const SizedBox.shrink()
                : MovieRow(
                    title: title,
                    movies: f.take(20).toList(),
                    onTap: _open,
                    onSeeMore: onSeeMore,
                  );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}
