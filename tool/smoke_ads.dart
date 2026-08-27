// Loc quang cao tren playlist THAT roi phat thu bang libmpv.
// Tu tai playlist o day (khong dung HlsPreparer vi no keo theo Flutter).
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:app_xem_phim/data/hls_ad_filter.dart';

Future<String> get(Uri u) async {
  final r = await http.get(u, headers: {'User-Agent': 'Mozilla/5.0'});
  if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
  return r.body;
}

Future<void> main(List<String> a) async {
  MediaKit.ensureInitialized();
  var url = Uri.parse(a.first);
  var body = await get(url);
  if (body.contains('#EXT-X-STREAM-INF')) {
    final v = body.split('\n').map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'));
    url = url.resolve(v);
    body = await get(url);
  }
  final r = filterHlsAds(body, url);
  if (r == null) { print('khong phai playlist phan doan'); exit(1); }
  print('da cat: ${r.removedSegments} phan doan = ${r.removedSeconds.toStringAsFixed(1)}s');

  // Phuc vu qua HTTP noi bo, giong het cach app lam.
  final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  srv.listen((req) async {
    req.response.headers.contentType =
        ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
    req.response.write(r.playlist);
    await req.response.close();
  });
  final localUrl = 'http://127.0.0.1:${srv.port}/x.m3u8';
  print('phuc vu tai: $localUrl');

  final p = Player();
  await p.open(Media(localUrl), play: true);
  final d = await p.stream.duration.firstWhere((x) => x.inSeconds > 0)
      .timeout(const Duration(seconds: 30), onTimeout: () => Duration.zero);
  print('thoi luong sau khi loc: ${d.inSeconds}s (goc 4258s)');
  await p.seek(const Duration(minutes: 10));
  await Future.delayed(const Duration(seconds: 6));
  print('tua toi 600s -> dang o ${p.state.position.inSeconds}s, dang phat: ${p.state.playing}');
  await p.dispose();
  exit(0);
}
