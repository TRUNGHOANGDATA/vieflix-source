import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/data/hls_ad_filter.dart';

final _base = Uri.parse(
    'https://v7.kkphimplayer7.com/20260806/aoSy5dFp/3500kb/hls/index.m3u8');

void main() {
  test('bỏ phân đoạn quảng cáo, giữ nguyên phân đoạn phim', () {
    const p = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-PLAYLIST-TYPE:vod
#EXT-X-TARGETDURATION:8
#EXT-X-KEY:METHOD=NONE
#EXTINF:7.8,
aaaaaaaa.ts
#EXTINF:4.0,
bbbbbbbb.ts
#EXT-X-DISCONTINUITY
#EXTINF:5.9,
convertv8/quangcao1.ts
#EXT-X-DISCONTINUITY
#EXTINF:2.6,
/v8/abc123/segment_0001.ts
#EXT-X-DISCONTINUITY
#EXTINF:6.0,
cccccccc.ts
#EXT-X-ENDLIST
''';
    final r = filterHlsAds(p, _base)!;
    expect(r.removedSegments, 2);
    expect(r.removedSeconds, closeTo(8.5, 0.001));

    final lines = r.playlist.trim().split('\n');
    final segs = lines.where((l) => !l.startsWith('#')).toList();
    expect(segs, [
      'https://v7.kkphimplayer7.com/20260806/aoSy5dFp/3500kb/hls/aaaaaaaa.ts',
      'https://v7.kkphimplayer7.com/20260806/aoSy5dFp/3500kb/hls/bbbbbbbb.ts',
      'https://v7.kkphimplayer7.com/20260806/aoSy5dFp/3500kb/hls/cccccccc.ts',
    ]);
    // Thẻ đầu playlist phải còn nguyên, nếu không trình phát từ chối.
    expect(lines.first, '#EXTM3U');
    expect(r.playlist, contains('#EXT-X-ENDLIST'));
    expect(r.playlist, contains('#EXT-X-KEY:METHOD=NONE'));
    // Không được để lại DISCONTINUITY mồ côi của quảng cáo đã cắt.
    expect(r.playlist.contains('#EXT-X-DISCONTINUITY'), isFalse);
    // Số #EXTINF phải khớp số phân đoạn còn lại.
    expect('#EXTINF'.allMatches(r.playlist).length, 3);
  });

  test('playlist sạch thì không đụng vào', () {
    const p = '''
#EXTM3U
#EXTINF:7.8,
aaaaaaaa.ts
#EXTINF:4.0,
bbbbbbbb.ts
#EXT-X-ENDLIST
''';
    final r = filterHlsAds(p, _base)!;
    expect(r.hasAds, isFalse);
    expect(r.removedSegments, 0);
    expect('#EXTINF'.allMatches(r.playlist).length, 2);
  });

  test('giữ DISCONTINUITY thật (chỗ nối của phim), chỉ bỏ cái của quảng cáo', () {
    const p = '''
#EXTM3U
#EXTINF:4.0,
aaaaaaaa.ts
#EXT-X-DISCONTINUITY
#EXTINF:4.0,
bbbbbbbb.ts
#EXT-X-ENDLIST
''';
    final r = filterHlsAds(p, _base)!;
    expect(r.hasAds, isFalse);
    expect(r.playlist, contains('#EXT-X-DISCONTINUITY'));
  });

  test('playlist master (chưa có phân đoạn) trả null', () {
    const p = '''
#EXTM3U
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=3500000,RESOLUTION=1920x1080
3500kb/hls/index.m3u8
''';
    expect(filterHlsAds(p, _base), isNull);
  });

  test('thư mục NHIỀU phân đoạn nhất mới là phim, không cứng nhắc theo tên', () {
    // Host đổi cách đặt tên: phim nằm trong thư mục con, quảng cáo ở gốc.
    const p = '''
#EXTM3U
#EXTINF:4.0,
v2/parts/s1.ts
#EXTINF:4.0,
v2/parts/s2.ts
#EXTINF:4.0,
v2/parts/s3.ts
#EXTINF:5.0,
quangcao.ts
#EXT-X-ENDLIST
''';
    final r = filterHlsAds(p, _base)!;
    expect(r.removedSegments, 1);
    expect(r.removedSeconds, closeTo(5.0, 0.001));
    expect(r.playlist, contains('v2/parts/s1.ts'));
    expect(r.playlist.contains('/hls/quangcao.ts'), isFalse);
  });
}
