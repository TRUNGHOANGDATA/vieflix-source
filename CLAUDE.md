# VieFlix — bối cảnh dự án

App xem phim kiểu Netflix/RoPhim, tiếng Việt, nền tối/đỏ, **làm cho gia đình dùng**.
Flutter + Riverpod. Package `com.vieflix.app_xem_phim`. Phiên bản hiện tại: xem
`kAppVersion` trong `lib/data/update_checker.dart` (1.0.57 lúc viết, 10/2026).

Chủ dự án trao đổi bằng **tiếng Việt**, hay báo lỗi bằng ảnh chụp màn hình + một
câu, và giao việc trọn gói ("commit và phát hành", "push đi" = làm hết các bước).
Giải thích kết quả bằng lời thường, ít thuật ngữ.

## Nền tảng (cả ba đều đang dùng thật)
| Nền tảng | Cách phát hành | Ghi chú |
|---|---|---|
| Windows | bộ cài Inno Setup `VieFlix-Setup-vX.Y.Z.exe` | WebView2; tự cập nhật im lặng (cài per-user) |
| Android TV box | `VieFlix-TV.apk` (tên CỐ ĐỊNH) | điều khiển D-pad; có box yếu (KICKPI) |
| iPad | `VieFlix-vX.Y.Z.ipa` không ký | cài bằng AltStore/Sideloadly, chữ ký Apple ID miễn phí sống 7 ngày |

## Bản đồ code
- **Nguồn phim** (`lib/data/`): `nguonc_api.dart` (phim.nguonc.com — chỉ có link
  **embed** streamc.xyz), `phimapi_source.dart` (phimapi.com — có **m3u8**; slug gắn
  tiền tố `pa:`). `aggregate_source.dart` gộp danh mục (nguonc ưu tiên, khử trùng theo
  tên gốc bỏ dấu + năm). `stream_sources.dart`: chọn nguồn mặc định Thuyết minh >
  Lồng tiếng > khác; cùng loại tiếng thì m3u8 trước embed.
- **Trình phát** `lib/player/player_screen.dart` có HAI đường:
  1. **Native** khi có m3u8 — Windows/iPad: media_kit/libmpv; **Android/TV: ExoPlayer**
     (`video_player`, `VideoViewType.platformView` = SurfaceView, `_openExo`). `hls_source.dart` +
     `hls_ad_filter.dart` cắt quảng cáo chèn trong luồng, phục vụ lại qua HTTP 127.0.0.1.
  2. **WebView** (flutter_inappwebview) cho embed — script tiêm nằm trong
     `lib/player/ad_blocker.dart`: `kAntiAdUserScript` (đầu trang: chống QC / guard /
     dò devtool), `kPlayerBridgeScript` (pause/tua/đọc vị trí), `kAutoPlayScript`,
     `kGentleAutoPlayScript` (iPad). `lib/data/referer_gate.dart`: cổng HTTP nội bộ
     sinh Referer cho streamc.xyz.
- Khác: đồng bộ "đang xem/yêu thích" bằng mã ngắn qua dpaste.com (`sync_service.dart`);
  TMDB (`tmdb_api.dart`, khóa nhúng lúc build `--dart-define=TMDB_KEY=...` hoặc người
  dùng nhập ở Cài đặt); cập nhật qua GitHub Releases (`update_checker.dart`,
  `update_flow.dart`); ngày hết hạn chữ ký iPad (`ios_cert.dart`).

## Bài học ở trình phát — ĐỪNG đảo lại
Mỗi điều từng làm hỏng phim thật; chú thích `⚠️` trong code ghi chi tiết.
- Trang embed nguonc đổi lớp bảo vệ liên tục. **Không** ẩn phần tử theo class quảng
  cáo (đó là mồi dò chặn QC → phim bị dừng). `window.open` phải trả **cửa sổ giả**,
  không trả null. **Không** bọc/sửa `jwplayer.setup` (player của nguồn init hỏng).
- Bộ dò DevTools của trang luôn báo nhầm trong app, vì plugin WebView2 bật CDP
  `Runtime.enable` để nghe console. Bản r25 (10/2026) được vá bằng cách móc
  `JSON.parse` để tắt `tvc` (quảng cáo đầu phim), `ads`, `browserGuard.*`, và cho
  `console.debug` thành no-op. Dấu hiệu trong log: `"/stream-guard/"` rồi
  `CHAN quang cao cuop trang -> https://phim.nguonc.com/` + `CONNECTION_ABORTED`.
- streamc.xyz cần Referer khác rỗng (thiếu → 403 Cloudflare). Windows/iPad: WebView2 vứt
  header Referer tự đặt → đi qua cổng `RefererGate`; luật chặn cướp trang phải luôn cho
  qua URL cổng. **Android ngược lại** (1.0.63): plugin Android nạp lại mọi điều hướng
  khung chính từ phía app nên cú nhảy của cổng mất Referer → Android BỎ cổng, gắn thẳng
  header (`RefererGate.headerFor`). Lưới an toàn: khung chính 403 → tự đổi nguồn.
- iOS cũng dùng **UA máy tính Windows** + giả `navigator.platform`/`maxTouchPoints`
  (nhánh Apple của trang cần ServiceWorker, WKWebView không có). iPad tự phát **nhẹ
  tay**, không dội `play()`.
- Đổi tập/nguồn: **dựng lại** WebView (key `_navSeq`), không `loadUrl` đè.
- Windows: luôn tiêm lại script bằng `evaluateJavascript` (onLoadStop + nhịp tự lành
  `_syncState`); script tiêm lặp phải có cờ chống chạy lặp. `ContentBlocker` crash
  trên Windows.
- **Android/TV phát m3u8 bằng ExoPlayer + SurfaceView, ĐỪNG quay lại mpv** (1.0.65): mpv
  chép mỗi khung qua GPU nên box chip yếu chỉ ra vài fps; ExoPlayer đã xác nhận mượt trên box
  thật (như FPT Play/VieON). Giảm tải mpv ở 1.0.64 không ăn thua. Giữ `EnableImpeller=false`
  (Skia) trong AndroidManifest và chỉ setState khi vị trí sang giây mới.
- Android build: ghim **AGP 8.7.3 + Kotlin 2.1.10 + Gradle 8.10.2** (AGP 9 phá
  flutter_inappwebview); APK chỉ đóng thư viện ARM.

## Chẩn đoán
- Log app (`vlog(tag, msg)`, viết không dấu): Windows
  `%APPDATA%\VieFlix\VieFlix\player-debug.log`; Android
  `/data/data/com.vieflix.app_xem_phim/files/player-debug.log` (lấy bằng
  `tool/tv.ps1` qua adb); iPad: app Files → "Trên iPad tôi" → VieFlix.
- **Trước khi đọc log**: chắc rằng người dùng đang chạy bản build MỚI (họ hay chạy
  `build\windows\x64\runner\Release\VieFlix.exe`) — so giờ `data\app.so` với giờ sửa code.
- **nguonc hỏng → dùng skill `sua-nguonc`.** Soi trang bằng
  `python tool/nguonc_repro.py <link embed> [--app] [--dump DIR]` (Playwright + Edge;
  `--app` tiêm đúng `kAntiAdUserScript`). `curl` luôn ăn 403 Cloudflare. WebKit (thay cho
  iPad): `tool/webkit-repro/` + workflow "WebKit repro" trên runner macOS.
- Thử Android trên máy tính (box thật không ADB được): AVD `vf30`
  (`ANDROID_AVD_HOME=H:/Android/avd`). Tạm bỏ dòng `excludes` x86 trong
  `android/app/build.gradle.kts` → `flutter build apk --profile --target-platform android-x64`
  → `adb install` → `git checkout` lại file gradle. WebView máy ảo cũ nên nguonc ở đó
  không đại diện cho TV thật.

## Skill của dự án (`.claude/skills/`, đi theo repo)
- `release-vieflix` — phát hành bản mới (Windows + Android + iPad) và push source.
- `sua-nguonc` — chẩn đoán + vá khi phim nguồn nguonc hỏng.

## Phát hành
Theo skill `.claude/skills/release-vieflix/SKILL.md`. Tóm tắt: tăng phiên bản ở **3
chỗ** (`kAppVersion`, `version:` trong pubspec với versionCode `X*10000+Y*100+Z`,
`MyAppVersion` trong `installer/VieFlix.iss`) → commit + push → kích workflow
"Build iOS IPA" → build Windows + bộ cài + APK → `gh release create` với **3 file** →
kiểm bằng API. Chạy `flutter` bằng Bash, không qua PowerShell pipeline.

## Repo & tài sản cần giữ
- Source: `TRUNGHOANGDATA/vieflix-source` (public, nhánh `master`).
- Bản tải: `TRUNGHOANGDATA/vieflix` (public). **Mọi app đã cài đều kiểm tra bản mới ở
  repo này** (`kReleaseRepo` ghi cứng). Muốn đổi sang repo/tài khoản khác thì phải phát
  hành MỘT bản cuối từ repo cũ đã trỏ sang repo mới, nếu không các máy cũ không bao
  giờ thấy bản mới.
- Link tải cố định cho TV: `.../releases/latest/download/VieFlix-TV.apk`, link ngắn
  `tinyurl.com/23h3geuo`.
- **Khóa ký Android** `android/vieflix-release.jks` + `android/key.properties`: KHÔNG có
  trong git (bị .gitignore), chỉ nằm trên máy dev. **Mất là mất khả năng cập nhật đè
  trên mọi TV box** (phải gỡ app, mất dữ liệu). Mẫu: `android/key.properties.example`;
  hướng dẫn: `docs/ANDROID_TV.md`. Chữ ký đúng: CN=VieFlix, SHA-256 bắt đầu `5068a120`.

## Quy ước
- Chú thích **tiếng Việt có dấu, giải thích VÌ SAO** (đo được gì, đã thử gì hỏng);
  chỗ nguy hiểm đánh dấu `⚠️`. Giữ đúng giọng này khi viết code mới.
- Commit tiếng Việt kiểu `fix(player): ...`, `feat(ios): ...`,
  `chore(release): X.Y.Z — bump kAppVersion/pubspec/installer`; bản sửa và bản tăng
  phiên bản là hai commit riêng.
- Hành vi quan trọng của script chống QC được khoá bằng test chuỗi trong
  `test/ad_blocker_test.dart`. Chạy `flutter analyze lib test` + `flutter test` trước
  khi commit.
- Môi trường máy dev hiện tại: Flutter `H:/flutter`, JDK 17
  `H:/Android/jdk17/jdk-17.0.20+8`, SDK `H:/Android/Sdk`, build APK cần `TEMP=C:\Temp`
  (đường dẫn 8.3 làm Gradle chết), Inno Setup 6, `gh` CLI.
