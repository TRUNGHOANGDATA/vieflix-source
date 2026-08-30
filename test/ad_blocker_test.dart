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

  test('adUrlFilters trả về danh sách regex không rỗng', () {
    expect(adUrlFilters().isNotEmpty, true);
    expect(adUrlFilters().length, kAdHosts.length);
    expect(adUrlFilters().any((f) => f.contains('amung')), true);
  });

  test('adContentBlockers KHÔNG ném lỗi (Windows trả rỗng)', () {
    expect(() => adContentBlockers(), returnsNormally);
  });

  group('chặn quảng cáo cướp khung chính', () {
    test('registrableDomain bỏ tiền tố con, hiểu cả đuôi hai cấp', () {
      expect(registrableDomain('player.phim.nguonc.com'), 'nguonc.com');
      expect(registrableDomain('phimapi.com'), 'phimapi.com');
      expect(registrableDomain('v7.kkphimplayer7.com'), 'kkphimplayer7.com');
      expect(registrableDomain('abc.xyz.com.vn'), 'xyz.com.vn');
      expect(registrableDomain('127.0.0.1:8080'), '0.1');
    });

    test('cùng site thì khác tên miền con vẫn tính là một', () {
      expect(sameSite('https://phim.nguonc.com/a', 'https://player.nguonc.com/b'), isTrue);
      expect(sameSite('https://phim.nguonc.com/a', 'https://cobac123.com/x'), isFalse);
    });

    test('sau khi phim đã tải xong, nhảy sang site khác là quảng cáo -> chặn', () {
      expect(
        isHijackNavigation(
          currentUrl: 'https://phim.nguonc.com/embed/abc',
          targetUrl: 'https://trangcobac.com/landing',
          isMainFrame: true,
          pageLoadedOnce: true,
        ),
        isTrue,
      );
    });

    test('lúc trang đang tải lần đầu thì KHÔNG chặn (nguồn có thể tự chuyển hướng)', () {
      expect(
        isHijackNavigation(
          currentUrl: 'https://phim.nguonc.com/embed/abc',
          targetUrl: 'https://cdn-khac.com/player',
          isMainFrame: true,
          pageLoadedOnce: false,
        ),
        isFalse,
      );
    });

    test('iframe con đi đâu kệ nó — player thật thường nằm trong iframe khác miền', () {
      expect(
        isHijackNavigation(
          currentUrl: 'https://phim.nguonc.com/embed/abc',
          targetUrl: 'https://cdn-video.com/play',
          isMainFrame: false,
          pageLoadedOnce: true,
        ),
        isFalse,
      );
    });

    test('vẫn trong cùng site thì cho qua', () {
      expect(
        isHijackNavigation(
          currentUrl: 'https://phim.nguonc.com/embed/abc',
          targetUrl: 'https://phim.nguonc.com/embed/tap-2',
          isMainFrame: true,
          pageLoadedOnce: true,
        ),
        isFalse,
      );
    });

    test('about:blank / data: không tính là điều hướng quảng cáo', () {
      for (final u in ['about:blank', 'data:text/html,x', '']) {
        expect(
          isHijackNavigation(
            currentUrl: 'https://phim.nguonc.com/embed/abc',
            targetUrl: u,
            isMainFrame: true,
            pageLoadedOnce: true,
          ),
          isFalse,
          reason: u,
        );
      }
    });
  });

  group('kịch bản chống quảng cáo', () {
    test('window.open trả CỬA SỔ GIẢ chứ không trả null', () {
      // Trang embed của nguồn chỉ chạy player khi mở được popup; trả null là nó
      // gọi blockPlayer() và xoá luôn link phim.
      expect(kAntiAdUserScript, contains('window.open = function'));
      expect(kAntiAdUserScript.contains('window.open = function () { return null; }'),
          isFalse,
          reason: 'trả null sẽ bị nguồn phát hiện là chặn quảng cáo');
      expect(kAntiAdUserScript, contains('closed: false'));
      expect(kAntiAdUserScript, contains('fake.self = fake'));
    });

    test('vẫn giữ các lớp chặn khác', () {
      expect(kAntiAdUserScript, contains('devtoolsDetector'));
      expect(kAntiAdUserScript, contains('advertising'));
    });
  });
}
