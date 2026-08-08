import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/local_store.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: 'App Xem Phim',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const AppShell(),
    );
  }
}
