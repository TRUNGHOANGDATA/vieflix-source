import 'package:flutter/material.dart';
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
/// - Tự cuộn vào tầm nhìn khi được chọn (trong danh sách cuộn).
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

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = context;
      if (ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
      onShowFocusHighlight: (f) {
        if (f != _focused) setState(() => _focused = f);
        if (f) _ensureVisible();
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
