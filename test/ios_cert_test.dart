import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/data/ios_cert.dart';

/// Dựng lại đúng hình dạng thật của embedded.mobileprovision: plist XML bị kẹp
/// giữa hai khối nhị phân của lớp ký CMS.
List<int> _hoSo(String plist) => [
      ...[0x30, 0x82, 0x0a, 0x00, 0xff, 0xfe, 0x00, 0x01], // rác nhị phân
      ...latin1.encode(plist),
      ...[0x00, 0x82, 0xab, 0xcd], // rác nhị phân
    ];

const _plistMau = '''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>Name</key><string>VieFlix</string>
  <key>CreationDate</key><date>2026-09-03T15:00:00Z</date>
  <key>ExpirationDate</key><date>2026-09-10T15:00:00Z</date>
</dict></plist>''';

void main() {
  test('đọc được ngày hết hạn kẹp giữa phần nhị phân', () {
    final d = IosCert.parseExpiry(_hoSo(_plistMau));
    expect(d, isNotNull);
    expect(d!.toUtc(), DateTime.utc(2026, 9, 10, 15));
  });

  test('lấy ĐÚNG ExpirationDate, không nhầm sang CreationDate', () {
    final d = IosCert.parseExpiry(_hoSo(_plistMau))!.toUtc();
    expect(d.day, 10); // không phải ngày 3
  });

  test('hồ sơ không có ngày / rác / rỗng thì trả null chứ không ném lỗi', () {
    expect(IosCert.parseExpiry(_hoSo('<?xml version="1.0"?><plist><dict>'
        '<key>Name</key><string>X</string></dict></plist>')), isNull);
    expect(IosCert.parseExpiry([0x00, 0xff, 0x10, 0x92]), isNull);
    expect(IosCert.parseExpiry([]), isNull);
  });

  test('đếm ngày còn lại, hết hạn thì ra số âm', () {
    final het = DateTime(2026, 9, 10, 15);
    expect(IosCert.daysLeft(het, now: DateTime(2026, 9, 3, 15)), 7);
    expect(IosCert.daysLeft(het, now: DateTime(2026, 9, 9, 20)), 0); // còn <1 ngày
    expect(IosCert.daysLeft(het, now: DateTime(2026, 9, 12, 15)), -2);
  });
}
