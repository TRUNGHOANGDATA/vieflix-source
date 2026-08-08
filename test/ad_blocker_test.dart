import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/player/ad_blocker.dart';

void main() {
  test('chặn domain quảng cáo/tracker đã biết', () {
    expect(isAdUrl('https://whos.amung.us/widget/x.js'), true);
    expect(isAdUrl('https://waust.at/s.js'), true);
    expect(isAdUrl('https://a.propellerads.com/x'), true);
    expect(isAdUrl('https://www.google-analytics.com/analytics.js'), true);
  });

  test('KHÔNG chặn host cần cho phát video', () {
    expect(isAdUrl('https://embed14.streamc.xyz/embed.php?hash=abc'), false);
    expect(isAdUrl('https://ssl.p.jwpcdn.com/player/v/8.38.2/jwplayer.js'), false);
    expect(isAdUrl('https://phim.nguonc.com/api/film/x'), false);
  });

  test('adContentBlockers trả về rules không rỗng', () {
    expect(adContentBlockers().isNotEmpty, true);
  });
}
