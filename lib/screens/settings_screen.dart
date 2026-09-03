import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../data/update_checker.dart';
import '../data/update_flow.dart';
import '../data/sync_service.dart';
import '../data/movie_source.dart';
import '../data/ios_cert.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _ctrl;
  bool _checking = false;
  bool _syncing = false;

  /// Ngày hết hạn chữ ký (chỉ iPad cài qua Sideloadly/AltStore mới có).
  DateTime? _hetHan;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(tmdbKeyProvider));
    IosCert.expiry().then((d) {
      if (mounted && d != null) setState(() => _hetHan = d);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Bật/tắt một nguồn phim. Luôn giữ ít nhất một nguồn để danh mục không rỗng.
  Future<void> _toggleSource(String id, bool on) async {
    final cur = ref.read(enabledSourcesProvider);
    if (!on && cur.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: kRed,
        content: Text('Phải bật ít nhất một nguồn phim'),
      ));
      return;
    }
    final next = {...cur};
    on ? next.add(id) : next.remove(id);
    ref.read(enabledSourcesProvider.notifier).state = next;
    await ref.read(storeProvider).setSourceEnabled(id, on);
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

  /// Tạo mã đồng bộ: đóng gói dữ liệu -> đẩy lên mạng -> hiện mã cho máy kia nhập.
  Future<void> _createSyncCode() async {
    setState(() => _syncing = true);
    try {
      final data = ref.read(storeProvider).exportData();
      final code = await SyncService().upload(data);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: kSurface,
          title: const Text('Mã đồng bộ của bạn', style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ở máy KIA: mở Cài đặt → "Nhập mã đồng bộ" → gõ đúng mã này:',
                style: TextStyle(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: kBg, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kRed, width: 2),
              ),
              child: SelectableText(code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kAmber, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3)),
            ),
            const SizedBox(height: 8),
            const Text('Mã phân biệt chữ HOA/thường, dùng được trong 1 năm.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: kRed, content: Text('Đã sao chép mã')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép'),
            ),
            ElevatedButton(
              autofocus: true,
              style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(c),
              child: const Text('Xong'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text('Không tạo được mã: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Nhập mã đồng bộ: hỏi mã -> tải gói về -> gộp vào máy này.
  Future<void> _enterSyncCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Nhập mã đồng bộ', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2),
          decoration: InputDecoration(
            hintText: 'Gõ mã từ máy kia…',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true, fillColor: kBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Nhập'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (code == null || code.trim().isEmpty) return;
    setState(() => _syncing = true);
    try {
      final data = await SyncService().download(code);
      final (pc, fc) = await ref.read(storeProvider).importData(data);
      ref.read(homeRefreshProvider.notifier).state++; // vẽ lại "Xem tiếp"
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: kRed,
            content: Text('Đã nhận $pc mục đang xem, $fc phim yêu thích ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: kRed, content: Text('Không nhập được: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
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

  /// Dòng hạn chữ ký. Chỉ hiện trên bản cài kiểu sideload — máy khác không có
  /// hồ sơ ký nên [IosCert.expiry] trả null và dòng này không tồn tại.
  Widget _chuKy(DateTime het) {
    final con = IosCert.daysLeft(het);
    final hai = het.day.toString().padLeft(2, '0');
    final thang = het.month.toString().padLeft(2, '0');
    final ngay = '$hai/$thang/${het.year}';

    final (String chu, Color mau) = con < 0
        ? ('Chữ ký đã hết hạn $ngay — cắm cáp ký lại để mở được app', kRed)
        : con == 0
            ? ('Chữ ký hết hạn HÔM NAY ($ngay) — ký lại ngay', kRed)
            : con <= 2
                ? ('Chữ ký hết hạn $ngay — còn $con ngày, nên ký lại sớm', kAmber)
                : ('Chữ ký hết hạn $ngay — còn $con ngày', Colors.white70);

    return Row(children: [
      Icon(con <= 2 ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
          color: mau, size: 15),
      const SizedBox(width: 6),
      Expanded(
        child: Text(chu,
            style: TextStyle(
                color: mau,
                fontSize: 13,
                fontWeight: con <= 2 ? FontWeight.bold : FontWeight.normal)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ref.watch(tmdbKeyProvider).isNotEmpty;
    final enabled = ref.watch(enabledSourcesProvider);
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
              if (_hetHan != null) ...[
                const SizedBox(height: 6),
                _chuKy(_hetHan!),
              ],
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
      const SizedBox(height: 16),
      // --- Đồng bộ giữa các máy ---
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.sync, color: Colors.white70, size: 22),
            SizedBox(width: 12),
            Text('Đồng bộ giữa các máy',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Mang danh sách "đang xem" và "yêu thích" sang máy/TV khác bằng một mã ngắn. '
            'Máy này bấm "Tạo mã", máy kia bấm "Nhập mã" rồi gõ mã vào.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
              onPressed: _syncing ? null : _createSyncCode,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Tạo mã đồng bộ'),
            ),
            OutlinedButton.icon(
              onPressed: _syncing ? null : _enterSyncCode,
              icon: const Icon(Icons.cloud_download, color: Colors.white),
              label: const Text('Nhập mã đồng bộ', style: TextStyle(color: Colors.white)),
            ),
            if (_syncing)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          ]),
        ]),
      ),
      const SizedBox(height: 24),
      // --- Nguồn phim ---
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.dns_outlined, color: Colors.white70, size: 22),
            SizedBox(width: 12),
            Text('Nguồn phim',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'App gộp phim từ nhiều nguồn: nguồn đầu được ưu tiên, phim nào nguồn đó '
            'chưa có thì nguồn sau bù vào. Tắt bớt nếu muốn xem của riêng một nguồn.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 4),
          for (final src in ref.watch(allSourcesProvider))
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kRed,
              value: enabled.contains(src.id),
              title: Text(sourceLabel(src.id),
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                src.id == kSrcNguonc
                    ? 'phim.nguonc.com — nguồn gốc của app'
                    : 'phimapi.com — kho phim lớn, có sẵn link phát trực tiếp',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onChanged: (v) => _toggleSource(src.id, v),
            ),
          if (enabled.length <= 1)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Phải bật ít nhất một nguồn.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
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
