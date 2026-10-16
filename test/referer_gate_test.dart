import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/data/referer_gate.dart';

void main() {
  tearDown(() => RefererGate.shutdown());

  test('Android: KHÔNG qua cổng, gắn thẳng Referer (cổng làm mất Referer trên Android)', () async {
    RefererGate.debugHeaderInsteadOfGate = true;
    addTearDown(() => RefererGate.debugHeaderInsteadOfGate = null);
    const target = 'https://embed11.streamc.xyz/embed.php?hash=abc';
    expect(await RefererGate.urlFor(target), target);
    expect(RefererGate.headerFor(target), {'Referer': 'http://127.0.0.1/'});
    expect(RefererGate.headerFor('https://player.phimapi.com/x'), isNull);
  });

  test('Windows/iPad: vẫn đi cổng, không gắn header', () async {
    RefererGate.debugHeaderInsteadOfGate = false;
    addTearDown(() => RefererGate.debugHeaderInsteadOfGate = null);
    const target = 'https://embed11.streamc.xyz/embed.php?hash=abc';
    expect(RefererGate.headerFor(target), isNull);
    expect(await RefererGate.urlFor(target), startsWith('http://127.0.0.1:'));
  });

  test('chỉ đi vòng qua cổng với nguồn chặn hotlink', () {
    expect(RefererGate.needsGate('https://embed15.streamc.xyz/embed.php?hash=a'), isTrue);
    expect(RefererGate.needsGate('https://player.phimapi.com/x'), isFalse);
    expect(RefererGate.needsGate('khong-phai-url'), isFalse);
  });

  test('nguồn không chặn hotlink thì giữ nguyên link, không dựng máy chủ', () async {
    const u = 'https://player.phimapi.com/x';
    expect(await RefererGate.urlFor(u), u);
    expect(RefererGate.isGateUrl('http://127.0.0.1:1/g0'), isFalse);
  });

  test('trang cổng tự nhảy sang đúng link đích và xin Referer kiểu origin', () async {
    const target = 'https://embed15.streamc.xyz/embed.php?hash=abc&x=1';
    final gate = await RefererGate.urlFor(target);
    expect(gate, startsWith('http://127.0.0.1:'));
    expect(RefererGate.isGateUrl(gate), isTrue);

    final res = await (await HttpClient().getUrl(Uri.parse(gate))).close();
    expect(res.statusCode, 200);
    final body = await res.transform(utf8.decoder).join();
    // Link đích phải được nhúng ĐÃ THOÁT CHUỖI (có dấu & trong query).
    expect(body, contains('location.replace(${jsonEncode(target)})'));
    expect(body, contains('<meta name="referrer" content="origin">'));
  });

  test('đường dẫn lạ trả 404, không lộ trang nào khác', () async {
    await RefererGate.urlFor('https://embed15.streamc.xyz/embed.php?hash=abc');
    final gate = await RefererGate.urlFor('https://embed15.streamc.xyz/embed.php?hash=abc');
    final root = Uri.parse(gate).replace(path: '/khong-co');
    final res = await (await HttpClient().getUrl(root)).close();
    expect(res.statusCode, 404);
  });
}
