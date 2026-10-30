# Tái hiện trang embed nguonc (streamc.xyz) trên Edge thật — để biết nguồn đổi gì
# khi phim nguonc hỏng. curl luôn ăn 403 Cloudflare (bắt vân tay TLS) nên phải
# dùng trình duyệt thật. Playwright cũng bật CDP Runtime y như plugin WebView2,
# nên bẫy dò DevTools của trang kích giống hệt trong app.
#
# Cần: pip install playwright (dùng Edge có sẵn của Windows, khỏi tải trình duyệt).
#
#   python tool/nguonc_repro.py <link embed>          trang SẠCH (không script app)
#   python tool/nguonc_repro.py <link embed> --app    kèm kAntiAdUserScript như app
#   thêm --dump <thư mục>  để lưu mọi file JS/HTML của streamc.xyz mà đọc
#
# Link embed lấy trong player-debug.log (dòng "dung WebView voi url=...").
# Kết quả mong đợi khi app chạy tốt (--app): ở lại streamc.xyz, jw=playing, t tăng.
import asyncio, os, re, sys
from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')
STATE_JS = '''() => { var v = document.querySelector('video'), jw = null;
  try { jw = jwplayer().getState(); } catch (e) {}
  return JSON.stringify({host: location.host, jw: jw, t: v && +v.currentTime.toFixed(1),
    paused: v && v.paused, src: v && v.currentSrc.slice(0, 40)}); }'''


def app_script():
    src = open(os.path.join(ROOT, 'lib', 'player', 'ad_blocker.dart'), encoding='utf-8').read()
    m = re.search(r"const String kAntiAdUserScript = r'''(.*?)''';", src, re.S)
    assert m, 'không tìm thấy kAntiAdUserScript trong ad_blocker.dart'
    return m.group(1)


async def main(embed, use_app, dump):
    async with async_playwright() as p:
        b = await p.chromium.launch(channel='msedge', headless=False, args=[
            '--autoplay-policy=no-user-gesture-required', '--window-position=-2400,0'])
        ctx = await b.new_context(user_agent=UA, viewport={'width': 1280, 'height': 720})
        if use_app:
            await ctx.add_init_script(app_script())
        page = await ctx.new_page()
        n = [0]

        async def on_resp(r):
            if dump and 'streamc' in r.url and r.request.resource_type in ('script', 'document'):
                try:
                    n[0] += 1
                    name = '%02d_%s' % (n[0], re.sub(r'[^\w.]+', '_', r.url.split('?')[0])[-60:])
                    open(os.path.join(dump, name), 'wb').write(await r.body())
                except Exception as e:
                    print('  khong luu duoc', r.url[:80], e)

        page.on('response', lambda r: asyncio.ensure_future(on_resp(r)))
        page.on('framenavigated', lambda f: f == page.main_frame and print('NAV', f.url[:110]))
        page.on('console', lambda m: print('CONSOLE', m.type, m.text[:200]))
        # Referer khác rỗng là đủ qua luật hotlink của Cloudflare (xem referer_gate.dart).
        await page.goto(embed, referer='http://127.0.0.1/', wait_until='domcontentloaded')
        for i in range(6):
            await page.wait_for_timeout(4000)
            try:
                print(i, await page.evaluate(STATE_JS))
            except Exception as e:
                print(i, 'ERR', e)
            if i == 0:
                await page.mouse.click(640, 360)  # như người bấm Play
        await b.close()


if __name__ == '__main__':
    args = sys.argv[1:]
    if not args or args[0].startswith('-'):
        sys.exit(__doc__ or 'cách dùng: python tool/nguonc_repro.py <link embed> [--app] [--dump DIR]')
    dump = args[args.index('--dump') + 1] if '--dump' in args else None
    if dump:
        os.makedirs(dump, exist_ok=True)
    asyncio.run(main(args[0], '--app' in args, dump))
