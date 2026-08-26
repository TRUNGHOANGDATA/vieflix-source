// So sanh 2 cach tua: NGAY SAU open() (giong app) vs DOI CO THOI LUONG roi tua.
import 'dart:io';
import 'package:media_kit/media_kit.dart';

Future<int> tryIt(String url, bool waitForDuration) async {
  final p = Player();
  const target = Duration(minutes: 10);
  if (waitForDuration) {
    await p.open(Media(url), play: true);
    // doi den khi biet thoi luong
    await p.stream.duration.firstWhere((d) => d.inSeconds > 0);
    await p.seek(target);
  } else {
    await p.open(Media(url), play: true);
    await p.seek(target); // <-- y het app dang lam
  }
  await Future.delayed(const Duration(seconds: 6));
  final pos = p.state.position.inSeconds;
  await p.dispose();
  return pos;
}

Future<void> main(List<String> a) async {
  MediaKit.ensureInitialized();
  final url = a.first;
  final ngay = await tryIt(url, false);
  print('tua NGAY SAU open()      -> dang o ${ngay}s  ${(ngay-600).abs()<=20 ? "OK" : "HONG (bi bo qua)"}');
  final doi = await tryIt(url, true);
  print('tua SAU KHI co thoi luong -> dang o ${doi}s  ${(doi-600).abs()<=20 ? "OK" : "HONG"}');
  exit(0);
}
