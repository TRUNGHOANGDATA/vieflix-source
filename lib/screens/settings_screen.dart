import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../data/update_checker.dart';
import '../data/update_flow.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _ctrl;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(tmdbKeyProvider));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Bấm "Kiểm tra cập nhật": hỏi GitHub xem có bản mới hơn không.
  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final info = await UpdateChecker().check();
    if (!mounted) return;
    setState(() => _checking = false);
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kRed,
        content: Text('Bạn đang dùng bản mới nhất rồi ✓'),
      ));
      return;
    }
    // Có bản mới -> hỏi cập nhật ngay.
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSurface,
        title: Text('Đã có bản mới v${info.version}', style: const TextStyle(color: Colors.white)),
        content: Text(
          canAutoInstall(info)
              ? 'Cập nhật ngay để dùng bản mới nhất? App sẽ tự tải và cài.'
              : 'Mở trang tải bản mới?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Để sau')),
          ElevatedButton(
            autofocus: true,
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: Text(canAutoInstall(info) ? 'Cập nhật ngay' : 'Tải về'),
          ),
        ],
      ),
    );
    if (go == true && mounted) startUpdateFlow(context, info);
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
      // --- Phiên bản & cập nhật ---
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.info_outline, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Phiên bản ứng dụng',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('VieFlix v$kAppVersion', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
            onPressed: _checking ? null : _checkUpdate,
            icon: _checking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.system_update),
            label: Text(_checking ? 'Đang kiểm tra…' : 'Kiểm tra cập nhật'),
          ),
        ]),
      ),
      const SizedBox(height: 24),
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
