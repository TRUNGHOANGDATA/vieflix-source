import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'data/local_store.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'screens/shell.dart';

/// Môi trường WebView2 dùng chung (chỉ Windows). Cho phép video TỰ PHÁT
/// không cần cú bấm của người dùng — WebView2 mặc định chặn autoplay.
WebViewEnvironment? webViewEnvironment;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(ProviderScope(
    overrides: [
      storeProvider.overrideWithValue(store),
      tmdbKeyProvider.overrideWith((ref) => store.tmdbKey.isNotEmpty ? store.tmdbKey : kDefaultTmdbKey),
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
