# VieFlix Android TV — Thiết kế

Ngày: 2026-08-08

## Mục tiêu
Bản Android TV giữ nguyên chức năng bản PC (Trang chủ, Đang xem, Thư viện phim, Tìm kiếm,
Danh sách của tôi, Chi tiết, Trình phát chặn quảng cáo, Cài đặt TMDB), điều khiển tốt bằng
remote (D-pad), cập nhật trong app như PC, và tìm kiếm giọng nói nếu thiết bị hỗ trợ.

## Ràng buộc
- Thiết bị đích: Android TV box thật → giao APK đã ký, sideload.
- Android Studio + SDK cài KHÔNG dùng ổ C (ổ H: hoặc khác).
- Người dùng không code → viết toàn bộ code + hướng dẫn chi tiết bằng tiếng Việt.

## Các phần
1. **Thêm nền tảng Android**: `flutter create --platforms=android .`; cấu hình AndroidManifest cho
   Android TV — Leanback launcher intent, banner, `android.hardware.touchscreen` required=false,
   `android.software.leanback` required=false, landscape, INTERNET + REQUEST_INSTALL_PACKAGES.
2. **Điều khiển remote (D-pad)**: mọi widget tương tác focus được; hiệu ứng focus rõ (phóng to +
   viền); autofocus hợp lý mỗi màn; nút Back của remote quay lại/thoát player. Wrap MaterialApp bằng
   Shortcuts/FocusableActionDetector nơi cần; card có focus highlight.
3. **Trình phát TV**: giữ WebView + ad-block; nút chuyển tập focus được. Cố gắng chuyển phím D-pad/OK
   vào WebView (rủi ro: điều khiển trong khung video phụ thuộc trang nhúng).
4. **Cập nhật trong app**: cùng release GitHub chứa cả .zip (Windows) và .apk (Android).
   Trên Android: tải APK về bộ nhớ app rồi mở trình cài đặt (FileProvider + intent
   ACTION_VIEW/INSTALL_PACKAGE). Cần quyền REQUEST_INSTALL_PACKAGES. update_checker nhận diện .apk.
5. **Ký APK cố định**: tạo 1 keystore dùng lại mọi bản phát hành (nếu đổi khóa → không update đè được).
   Lưu keystore an toàn; cấu hình `android/key.properties` + `build.gradle` signingConfig release.
6. **Tìm kiếm giọng nói**: `speech_to_text`; nút mic ẩn nếu thiết bị không hỗ trợ.
7. **Quy trình phát hành**: cập nhật skill release để build cả Windows + APK, đăng cùng release,
   tăng version 1 lần cho cả hai.

## Rủi ro
- Điều khiển bên trong khung video bằng remote có thể chưa hoàn hảo (trang phát của nhà cung cấp).
- Tìm kiếm giọng nói phụ thuộc TV box có dịch vụ nhận giọng nói Google.

## Bàn giao
`app-release.apk` đã ký + hướng dẫn cài Android Studio (ổ không phải C), sideload APK lên TV, bật cập nhật.
