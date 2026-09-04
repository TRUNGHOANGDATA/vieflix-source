import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'data/local_store.dart';
import 'data/movie_source.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'screens/shell.dart';

/// Môi trường WebView2 dùng chung (chỉ Windows). Cho phép video TỰ PHÁT
/// không cần cú bấm của người dùng — WebView2 mặc định chặn autoplay.
WebViewEnvironment? webViewEnvironment;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Trình phát native (dùng cho link m3u8). Gọi sớm vì nó nạp thư viện libmpv.
  MediaKit.ensureInitialized();
  if (Platform.isWindows) {
    try {
      webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          additionalBrowserArguments: '--autoplay-policy=no-user-gesture-required',
        ),
      );
    } catch (_) {
      webViewEnvironment = null; // lỗi thì dùng môi trường mặc định
    }
  }
  final store = LocalStore();
  await store.init();
  // Lần đầu chạy trên máy này: đặt mặc định nguồn theo nền tảng (iOS tắt nguonc).
  await store.seedDefaultSourcesOnce();
  runApp(ProviderScope(
    overrides: [
      storeProvider.overrideWithValue(store),
      tmdbKeyProvider.overrideWith((ref) => store.tmdbKey.isNotEmpty ? store.tmdbKey : kDefaultTmdbKey),
      enabledSourcesProvider.overrideWith((ref) {
        final off = store.disabledSources;
        final on = ref
            .watch(allSourcesProvider)
            .map((s) => s.id)
            .where((id) => !off.contains(id))
            .toSet();
        // Không còn nguồn nào bật -> lấy nguồn ĐẦU TIÊN app dùng được trên máy này
        // (iOS: phimapi, vì nguonc không phát được — xem seedDefaultSourcesOnce).
        return on.isEmpty ? {Platform.isIOS ? kSrcPhimApi : kSrcNguonc} : on;
      }),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VieFlix',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const AppShell(),
    );
  }
}
