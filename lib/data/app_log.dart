import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Nhật ký chẩn đoán ghi ra FILE (không chỉ debugPrint — app GUI trên Windows/TV
/// không ai thấy stdout). Nhờ vậy khi phim lỗi, mở file này ra là biết vì sao.
///
/// Vị trí file:
///   Windows: %APPDATA%\VieFlix\VieFlix\player-debug.log
///   Android: /data/data/com.vieflix.app_xem_phim/files/player-debug.log
///            (lấy nhanh bằng: adb pull hoặc tool/tv.ps1)
class DiagLog {
  static File? _file;
  static bool _init = false;
  static final List<String> _pending = [];

  static Future<void> _ensure() async {
    if (_init) return;
    _init = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}player-debug.log');
      // Cắt bớt nếu file phình quá 512KB để khỏi đầy đĩa.
      if (await f.exists() && await f.length() > 512 * 1024) {
        await f.writeAsString('');
      }
      _file = f;
      if (_pending.isNotEmpty) {
        await f.writeAsString(_pending.join(), mode: FileMode.append, flush: true);
        _pending.clear();
      }
    } catch (_) {/* không ghi được thì thôi */}
  }

  static void write(String line) {
    final stamped = '${DateTime.now().toIso8601String()} $line\n';
    debugPrint(stamped.trimRight());
    final f = _file;
    if (f != null) {
      try { f.writeAsStringSync(stamped, mode: FileMode.append, flush: true); return; }
      catch (_) {}
    }
    if (_pending.length < 500) _pending.add(stamped);
    _ensure();
  }
}

/// Ghi một dòng chẩn đoán, gắn nơi phát sinh.
void vlog(String where, String msg) => DiagLog.write('VIEFLIX[$where] $msg');
