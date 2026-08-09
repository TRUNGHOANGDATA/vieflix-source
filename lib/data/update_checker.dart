import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

/// Phiên bản app hiện tại. MỖI lần phát hành bản mới phải TĂNG số này cho
/// khớp tag trên GitHub (vd tag `v1.0.1` -> đặt '1.0.1').
const String kAppVersion = '1.0.9';

/// Repo GitHub PUBLIC chỉ dùng để chứa bản tải, dạng 'chu-repo/ten-repo'.
/// Để rỗng nếu chưa cấu hình -> app bỏ qua kiểm tra cập nhật (không lỗi).
const String kReleaseRepo = 'TRUNGHOANGDATA/vieflix';

class UpdateInfo {
  final String version;   // vd '1.0.1'
  final String notes;     // ghi chú phát hành
  final String downloadUrl; // link tải bản mới (đúng nền tảng đang chạy)
  final bool isApk;       // true nếu link là file .apk (Android)
  final bool isInstaller; // true nếu link Windows là bộ cài .exe -> tự cài được
  UpdateInfo({required this.version, required this.notes, required this.downloadUrl, required this.isApk, this.isInstaller = false});
}

/// Kiểm tra bản mới qua GitHub Releases API (repo public, không cần token).
class UpdateChecker {
  Future<UpdateInfo?> check() async {
    if (kReleaseRepo.isEmpty) return null;
    try {
      final r = await http.get(
        Uri.parse('https://api.github.com/repos/$kReleaseRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;

      final tag = (j['tag_name'] ?? '').toString();
      final latest = tag.replaceFirst(RegExp(r'^[vV]'), '').trim();
      if (latest.isEmpty || !_isNewer(latest, kAppVersion)) return null;

      final assets = (j['assets'] as List? ?? const []);
      final pageUrl = (j['html_url'] ?? '').toString();

      // Chọn đúng file cho nền tảng đang chạy.
      String? apkUrl, exeUrl, zipUrl;
      for (final a in assets) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        final url = (a['browser_download_url'] ?? '').toString();
        if (url.isEmpty) continue;
        if (name.endsWith('.apk')) {
          apkUrl ??= url;
        } else if (name.endsWith('.exe')) {
          exeUrl ??= url; // bộ cài Windows -> tự cài được
        } else if (name.endsWith('.zip') || name.endsWith('.msix')) {
          zipUrl ??= url; // gói nén -> chỉ mở link tải
        }
      }
      final notes = (j['body'] ?? '').toString();

      if (Platform.isAndroid) {
        if (apkUrl != null) {
          return UpdateInfo(version: latest, notes: notes, downloadUrl: apkUrl, isApk: true);
        }
        // Không có APK -> mở trang release cho người dùng tự tải.
        return UpdateInfo(version: latest, notes: notes, downloadUrl: pageUrl, isApk: false);
      } else {
        // Windows: ưu tiên bộ cài .exe (tự cài); không có thì tới .zip; cuối cùng mở trang.
        if (exeUrl != null) {
          return UpdateInfo(version: latest, notes: notes, downloadUrl: exeUrl, isApk: false, isInstaller: true);
        }
        return UpdateInfo(version: latest, notes: notes, downloadUrl: zipUrl ?? pageUrl, isApk: false);
      }
    } catch (_) {
      return null; // lỗi mạng / repo chưa có release -> im lặng bỏ qua
    }
  }

  // So sánh phiên bản kiểu 1.2.3
  bool _isNewer(String a, String b) {
    List<int> nums(String s) => s
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final pa = nums(a), pb = nums(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Windows: mở link tải bằng trình duyệt mặc định.
  Future<void> openDownload(String url) async {
    if (url.isEmpty) return;
    try {
      if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', url]);
      }
    } catch (_) {}
  }

  /// Android: tải file APK về thư mục nội bộ của app, báo tiến độ 0..1.
  /// Trả về file đã tải, hoặc null nếu lỗi.
  Future<File?> downloadApk(String url, {void Function(double progress)? onProgress}) async {
    if (url.isEmpty) return null;
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req);
      if (res.statusCode != 200) return null;
      final total = res.contentLength ?? 0;

      // Lưu APK ra bộ nhớ NGOÀI của app (trình cài đặt đọc dễ hơn bộ nhớ trong,
      // lại còn nhiều dung lượng) -> tránh "App not installed" trên TV box.
      Directory dir;
      try {
        dir = (await getExternalStorageDirectory()) ?? await getApplicationSupportDirectory();
      } catch (_) {
        dir = await getApplicationSupportDirectory();
      }
      final file = File('${dir.path}${Platform.pathSeparator}vieflix-update.apk');
      // Xoá file cũ nếu còn.
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.flush();
      await sink.close();
      // Kiểm tra đã tải đủ (file thiếu -> trình cài báo "App not installed").
      if (total > 0 && (await file.length()) != total) {
        try { await file.delete(); } catch (_) {}
        return null;
      }
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Windows: tải bộ cài .exe về thư mục tạm, báo tiến độ 0..1. Trả file hoặc null.
  Future<File?> downloadInstaller(String url, String version, {void Function(double progress)? onProgress}) async {
    if (url.isEmpty) return null;
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req);
      if (res.statusCode != 200) return null;
      final total = res.contentLength ?? 0;

      final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}VieFlix-Setup-v$version.exe');
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && onProgress != null) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Windows: chạy bộ cài ở chế độ im lặng (tự đóng app cũ, cài đè, mở lại)
  /// rồi THOÁT app để giải phóng khoá VieFlix.exe cho trình cài ghi đè.
  /// Không trả về nếu thành công (app đã exit); trả false nếu không khởi chạy được.
  Future<bool> runWindowsInstaller(File setup) async {
    try {
      await Process.start(
        setup.path,
        ['/SILENT', '/SUPPRESSMSGBOXES', '/NOCANCEL', '/FORCECLOSEAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
      // Cho trình cài kịp khởi động rồi thoát để mở khoá file.
      await Future.delayed(const Duration(milliseconds: 600));
      exit(0);
    } catch (_) {
      return false;
    }
  }

  /// Android: mở trình cài đặt để cập nhật đè lên bản đang chạy.
  /// Trả về false nếu người dùng chưa cấp quyền "cài từ nguồn không xác định".
  Future<bool> installApk(File file) async {
    try {
      // Xin quyền cài gói (Android sẽ mở màn hình cho phép nếu chưa bật).
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) return false;
      final res = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      return res.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }
}
