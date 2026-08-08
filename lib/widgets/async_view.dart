import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';

class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator(color: kRed)),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.white54, size: 48),
          const SizedBox(height: 8),
          const Text('Đã xảy ra lỗi khi tải dữ liệu', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          if (onRetry != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
        ]),
      ),
    );
  }
}
