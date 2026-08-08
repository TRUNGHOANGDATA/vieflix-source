import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Các phím "chọn/OK" trên remote TV + bàn phím: Enter, Select (nút OK D-pad),
/// Space, Enter bàn phím số, nút A tay cầm.
const Map<ShortcutActivator, Intent> kActivateShortcuts = {
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
};

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
