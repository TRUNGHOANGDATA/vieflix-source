import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(storeProvider).tmdbKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    await ref.read(storeProvider).setTmdbKey(key);
    ref.read(tmdbKeyProvider.notifier).state = key;
    ref.invalidate(recommendedProvider); // tính lại đề cử theo rating
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kRed,
        content: Text(key.isEmpty ? 'Đã xóa khóa TMDB' : 'Đã lưu khóa TMDB — rating sẽ hiển thị'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ref.watch(tmdbKeyProvider).isNotEmpty;
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Cài đặt', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Row(children: [
        const Text('Đánh giá phim (TMDB)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Icon(hasKey ? Icons.check_circle : Icons.error_outline, color: hasKey ? Colors.greenAccent : Colors.orangeAccent, size: 20),
      ]),
      const SizedBox(height: 8),
      const Text(
        'Nguồn phim không có sẵn điểm đánh giá. Dán khóa API TMDB (miễn phí) để app '
        'lấy điểm IMDb/TMDB và đề cử phim hay.',
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Dán API Key (v3 auth) ở đây...',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true, fillColor: kSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Lưu')),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () { _ctrl.clear(); _save(); },
          child: const Text('Xóa khóa', style: TextStyle(color: Colors.white)),
        ),
      ]),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cách lấy khóa TMDB (miễn phí)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('1. Vào themoviedb.org → Đăng ký tài khoản.\n'
              '2. Settings → API → Create → Developer → điền thông tin đơn giản.\n'
              '3. Copy dòng "API Key (v3 auth)" (~32 ký tự).\n'
              '4. Dán vào ô trên → Lưu.',
              style: TextStyle(color: Colors.white70, height: 1.6)),
        ]),
      ),
    ]);
  }
}
