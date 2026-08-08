import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
      body: Row(children: [
        NavigationRail(
          backgroundColor: Colors.black,
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          labelType: NavigationRailLabelType.all,
          selectedIconTheme: const IconThemeData(color: kRed),
          selectedLabelTextStyle: const TextStyle(color: kRed),
          unselectedIconTheme: const IconThemeData(color: Colors.white70),
          unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
          leading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('PHIM', style: TextStyle(color: kRed, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Trang chủ')),
            NavigationRailDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: Text('Duyệt')),
            NavigationRailDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: Text('Tìm kiếm')),
            NavigationRailDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: Text('Yêu thích')),
            NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Cài đặt')),
          ],
        ),
        const VerticalDivider(width: 1, color: Colors.white10),
        Expanded(child: pages[_i]),
      ]),
    );
  }
}
