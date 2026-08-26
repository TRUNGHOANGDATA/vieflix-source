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
  print('vi tri sau khi phat: ${p.state.position.inMilliseconds}ms, '
      'dang phat: ${p.state.playing}');

  // Tua tới phut thu 10 - kiem "xem tiep" co that su nhay dung cho khong.
  const target = Duration(minutes: 10);
  await p.seek(target);
  await Future.delayed(const Duration(seconds: 3));
  final after = p.state.position;
  final lech = (after - target).inSeconds.abs();
  print('sau khi tua toi ${target.inSeconds}s -> dang o ${after.inSeconds}s '
      '(lech ${lech}s) => ${lech <= 15 ? "TUA OK" : "TUA HONG"}');
  await p.dispose();
  exit(0);
}
