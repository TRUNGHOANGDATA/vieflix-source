import 'package:flutter/material.dart';
import '../widgets/top_nav.dart';
import 'home_screen.dart';
import 'browse_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), BrowseScreen(), SearchScreen(), MyListScreen(), SettingsScreen()];
    return Scaffold(
      body: Column(children: [
        TopNav(selected: _i, onSelect: (v) => setState(() => _i = v)),
        Expanded(child: pages[_i]),
      ]),
    );
  }
}
