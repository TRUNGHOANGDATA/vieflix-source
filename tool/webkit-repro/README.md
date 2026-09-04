# Tái hiện trang embed nguonc trên WebKit thật của Apple

iPad không cắm được Safari Web Inspector khi không có Mac. Thay vào đó chạy
Playwright **WebKit trên máy ảo macOS của GitHub Actions** — cùng WebCore và cùng
bộ media AVFoundation với iPad — bằng workflow `webkit-repro.yml`.

WebKit bản Windows/Linux của Playwright **không có MediaSource** nên vô dụng cho
việc này (jwplayer báo 102630 ngay lúc dựng, không phản ánh iPad).

`kAntiAdUserScript.js` / `kAutoPlayScript.js` là bản chép từ `lib/player/ad_blocker.dart`
lúc viết công cụ — sửa script trong app thì chép lại.
