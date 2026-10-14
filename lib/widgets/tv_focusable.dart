import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Các phím "chọn/OK" trên remote TV + bàn phím: Enter, Select (nút OK D-pad),
/// Space, Enter bàn phím số, nút A tay cầm.
const Map<ShortcutActivator, Intent> kActivateShortcuts = {
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
};

/// Đoạn văn dài dùng được trên TV: remote chọn tới (viền sáng) rồi bấm ▲▼ để
/// cuộn đọc. Khi đã cuộn hết đầu/cuối thì nhường phím cho phần khác -> vẫn đi
/// tiếp được bằng D-pad, không bị "kẹt" trong ô này.
class TvScrollableText extends StatefulWidget {
  final String text;
  final double maxHeight;
  const TvScrollableText({super.key, required this.text, this.maxHeight = 190});
  @override
  State<TvScrollableText> createState() => _TvScrollableTextState();
}

class _TvScrollableTextState extends State<TvScrollableText> {
  final _sc = ScrollController();
  bool _focused = false;

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    final up = e.logicalKey == LogicalKeyboardKey.arrowUp;
    if (!down && !up) return KeyEventResult.ignored;
    if (!_sc.hasClients) return KeyEventResult.ignored;

    final pos = _sc.position;
    // Đã ở cuối (bấm xuống) hoặc đầu (bấm lên) -> nhường phím để rời khỏi ô.
    if (down && pos.pixels >= pos.maxScrollExtent - 1) return KeyEventResult.ignored;
    if (up && pos.pixels <= 0) return KeyEventResult.ignored;

    final target = (pos.pixels + (down ? 80 : -80)).clamp(0.0, pos.maxScrollExtent);
    _sc.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: _onKey,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _focused ? kRed : Colors.transparent, width: 2),
          color: _focused ? Colors.white10 : Colors.transparent,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: SingleChildScrollView(
              controller: _sc,
              child: Text(widget.text, style: const TextStyle(color: Colors.white70, height: 1.5)),
            ),
          ),
          if (_focused)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('▲ ▼ để đọc tiếp', style: TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}

/// Bọc bất kỳ widget nào để dùng tốt với remote (D-pad):
/// - Sáng lên khi được chọn (focus): phóng to nhẹ + builder(focused) tự vẽ viền.
/// - Bấm OK/Enter để kích hoạt onPressed.
/// - Cuộn vào tầm nhìn khi được chọn: do [tvFocusPolicy] lo, không phải widget này.
/// Vẫn bấm chuột được như thường trên bản PC.
class FocusHighlight extends StatefulWidget {
  final Widget Function(bool focused) builder;
  final VoidCallback onPressed;
  final bool autofocus;
  final double scale;
  final FocusNode? focusNode;
  const FocusHighlight({
    super.key,
    required this.builder,
    required this.onPressed,
    this.autofocus = false,
    this.scale = 1.08,
    this.focusNode,
  });

  @override
  State<FocusHighlight> createState() => _FocusHighlightState();
}

class _FocusHighlightState extends State<FocusHighlight> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      shortcuts: kActivateShortcuts,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onPressed();
          return null;
        }),
      },
      // Cuộn tới ô được chọn do [tvRequestFocus] lo (chính sách focus chung
      // của app), KHÔNG tự cuộn ở đây nữa: xem ⚠️ ở tvRequestFocus.
      onShowFocusHighlight: (f) {
        if (f != _focused) setState(() => _focused = f);
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _focused ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: widget.builder(_focused),
        ),
      ),
    );
  }
}

/// Chính sách di chuyển focus chung cho cả app (gắn ở MaterialApp.builder, mọi
/// màn hình và hộp thoại đều thừa hưởng). Chỉ khác mặc định ở cách CUỘN tới ô
/// mới — xem [tvRequestFocus].
final tvFocusPolicy = ReadingOrderTraversalPolicy(requestFocusCallback: tvRequestFocus);

/// Chọn ô [node] rồi cuộn tới nó bằng MỘT cú trượt mượt.
///
/// ⚠️ Vì sao phải tự viết: mặc định Flutter NHẢY tức thì (không hiệu ứng) để ô
/// mới vừa lọt mép màn hình, trong khi FocusHighlight lại TRƯỢT thêm một lần nữa
/// để đưa ô ra giữa. Hai cú cuộn chồng nhau nên mỗi lần bấm ▲▼ trên remote trang
/// giật một cái rồi mới lướt — người dùng thấy "lên xuống không mượt".
///
/// Cách cuộn bây giờ:
/// - Trang DỌC: đưa CẢ HÀNG (tiêu đề + thẻ) ra giữa màn hình -> hàng đang chọn
///   luôn đứng một chỗ cố định, kiểu Netflix trên TV.
/// - Hàng NGANG: chỉ dịch khi thẻ sắp ra khỏi mép, và dịch đúng một ô (căn theo
///   ô của danh sách nên thẻ vẫn khít lề, không lòi nửa ảnh).
void tvRequestFocus(
  FocusNode node, {
  ScrollPositionAlignmentPolicy? alignmentPolicy,
  double? alignment,
  Duration? duration,
  Curve? curve,
}) {
  node.requestFocus();
  BuildContext? c = node.context;
  if (c == null) return;
  RenderObject? first;
  var s = Scrollable.maybeOf(c);
  while (s != null) {
    final obj = c!.findRenderObject();
    if (obj == null || !obj.attached) break;
    final pos = s.position;
    final item = _listItemOf(obj, pos);
    var policy = ScrollPositionAlignmentPolicy.explicit;
    if (pos.axis == Axis.horizontal) {
      // Ô nằm bên trái vùng nhìn -> kéo về mép trái; còn lại -> giữ trong mép phải.
      final reveal = RenderAbstractViewport.maybeOf(item)?.getOffsetToReveal(item, 0.0).offset;
      policy = (reveal != null && reveal < pos.pixels)
          ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
    }
    pos.ensureVisible(
      item,
      alignment: 0.5,
      alignmentPolicy: policy,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      targetRenderObject: first,
    );
    first ??= item;
    c = s.context;
    s = Scrollable.maybeOf(c);
  }
}

/// Ô của danh sách chứa [obj] (con trực tiếp của sliver). Căn theo ô thay vì
/// theo thẻ để vị trí cuộn trùng lưới ô (thẻ có lề trong ô). Ô to quá 90% màn
/// (vd. cả khối danh sách tập ở trang chi tiết) thì căn theo chính [obj], kẻo
/// đưa khối to ra giữa lại đẩy ô đang chọn khuất mất.
RenderObject _listItemOf(RenderObject obj, ScrollPosition pos) {
  RenderObject r = obj;
  while (r.parent != null && r.parent is! RenderSliver) {
    r = r.parent!;
  }
  if (r.parent is! RenderSliver || r is! RenderBox || !r.hasSize) return obj;
  final extent = pos.axis == Axis.vertical ? r.size.height : r.size.width;
  return extent <= pos.viewportDimension * 0.9 ? r : obj;
}
