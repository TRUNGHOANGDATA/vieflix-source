// Kiểm tra player native mở được link m3u8 thật (không cần cửa sổ).
// Chạy: PATH có libmpv-2.dll -> dart run tool/smoke_native.dart <m3u8>
import 'dart:async';
import 'dart:io';
import 'package:media_kit/media_kit.dart';

Future<void> main(List<String> args) async {
  MediaKit.ensureInitialized();
  final url = args.first;
  final p = Player();
  final done = Completer<String>();

  p.stream.duration.listen((d) {
    if (d.inSeconds > 0 && !done.isCompleted) {
      done.complete('OK - thoi luong ${d.inSeconds}s');
    }
  });
  p.stream.error.listen((e) {
    if (!done.isCompleted) done.complete('LOI - $e');
  });

  await p.open(Media(url), play: true);
  final r = await done.future.timeout(const Duration(seconds: 30),
      onTimeout: () => 'TIMEOUT - khong doc duoc thoi luong');
  print(r);
  final pos = p.state.position.inMilliseconds;
  print('vi tri sau khi phat: ${pos}ms, dang phat: ${p.state.playing}');
  await p.dispose();
  exit(0);
}
