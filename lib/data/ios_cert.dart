import 'dart:convert';
import 'dart:io';

/// Ngày hết hạn của CHỮ KÝ app trên iPad, đọc từ chính bản cài.
///
/// App được cài bằng Sideloadly/AltStore thì ký bằng Apple ID miễn phí, và chữ
/// ký đó **chỉ sống 7 ngày** — hết hạn là app không mở được nữa, phải cắm cáp ký
/// lại. Sideloadly là công cụ trên PC, không có app trên iPad, nên không có chỗ
/// nào đếm ngược. Nhưng lúc ký nó có nhúng hồ sơ `embedded.mobileprovision` vào
/// trong app, và trong đó ghi sẵn ngày hết hạn — đọc ra là biết.
///
/// Hồ sơ là tệp CMS/PKCS#7 nhị phân có KẸP một plist XML ở giữa. Không cần bóc
/// lớp chữ ký làm gì (cũng chẳng để làm gì): cắt đúng đoạn XML rồi lấy ngày ra.
class IosCert {
  /// Ngày hết hạn, hoặc null nếu không đọc được (máy không phải iOS, bản cài
  /// không kèm hồ sơ, hồ sơ lạ). Mọi trường hợp null đều nghĩa là "không biết"
  /// — người gọi ĐỪNG hiện gì cả, đừng đoán bừa một ngày.
  static Future<DateTime?> expiry() async {
    if (!Platform.isIOS) return null;
    try {
      final dir = File(Platform.resolvedExecutable).parent;
      final f = File('${dir.path}/embedded.mobileprovision');
      if (!await f.exists()) return null;
      return parseExpiry(await f.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  /// Tách ngày hết hạn từ nội dung thô của `embedded.mobileprovision`.
  /// Tách riêng khỏi phần đọc tệp để kiểm thử được.
  static DateTime? parseExpiry(List<int> bytes) {
    // latin1 để mọi byte đều ánh xạ 1-1 sang ký tự; phần nhị phân quanh plist
    // có thể không phải UTF-8 hợp lệ nên utf8.decode sẽ ném lỗi.
    final text = latin1.decode(bytes, allowInvalid: true);
    final start = text.indexOf('<?xml');
    final end = text.indexOf('</plist>');
    if (start < 0 || end < 0 || end <= start) return null;
    final plist = text.substring(start, end);

    final m = RegExp(
      r'<key>ExpirationDate</key>\s*<date>([^<]+)</date>',
      caseSensitive: false,
    ).firstMatch(plist);
    if (m == null) return null;
    return DateTime.tryParse(m.group(1)!.trim())?.toLocal();
  }

  /// Số ngày còn lại, làm tròn xuống. Âm nghĩa là đã hết hạn.
  static int daysLeft(DateTime expiry, {DateTime? now}) {
    final from = now ?? DateTime.now();
    return expiry.difference(from).inHours ~/ 24;
  }
}
