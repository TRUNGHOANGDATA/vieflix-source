# VieFlix cho Android TV — Hướng dẫn cài đặt & build (dành cho người không rành code)

Tài liệu này giúp bạn: (A) cài bộ công cụ Android **KHÔNG dùng ổ C**, (B) tạo khóa ký cố
định, (C) build ra file APK, (D) chép lên TV box và cài, (E) bật cập nhật trong app.

> Máy bạn hiện ĐÃ có Flutter tại `H:\flutter`. Chỉ còn thiếu **Android SDK**.

---

## A. Cài Android Studio + SDK (cài sang ổ khác C)

1. Tải Android Studio: https://developer.android.com/studio (bản Windows).
2. Chạy file cài. Ở bước chọn nơi cài:
   - **Install Location** (thư mục chương trình): đổi sang ví dụ `H:\Android\Android Studio`.
3. Mở Android Studio lần đầu → nó chạy **Setup Wizard**. Chọn **Custom**:
   - **Android SDK Location**: đổi sang ví dụ `H:\Android\Sdk` (KHÔNG để ổ C).
   - Tích các mục: **Android SDK**, **Android SDK Platform** (bản mới nhất), **Android SDK
     Build-Tools**, **Android SDK Command-line Tools**, **Android SDK Platform-Tools**.
   - Bấm Next → Accept → Finish để nó tải về (vài GB, chờ khá lâu).

   > Android Studio kèm sẵn Java (JDK) ở `...\Android Studio\jbr` — ta sẽ dùng nó để tạo khóa
   > ở bước B, không cần cài Java riêng.

4. **Báo cho Flutter biết SDK nằm đâu** (mở PowerShell):
   ```powershell
   & "H:\flutter\bin\flutter" config --android-sdk "H:\Android\Sdk"
   ```
5. **Chấp nhận điều khoản SDK**:
   ```powershell
   & "H:\flutter\bin\flutter" doctor --android-licenses
   ```
   Gõ `y` cho mọi câu hỏi.
6. Kiểm tra lại:
   ```powershell
   & "H:\flutter\bin\flutter" doctor
   ```
   Dòng **[√] Android toolchain** có dấu tick là đạt.

---

## B. Tạo khóa ký cố định (chỉ làm 1 lần, dùng mãi cho mọi bản)

⚠️ **RẤT QUAN TRỌNG:** Mọi bản APK phải ký bằng **cùng một khóa**. Nếu đổi khóa, TV sẽ báo
lỗi khi cập nhật và bạn phải gỡ app cài lại. Vì vậy tạo 1 lần rồi **giữ kỹ file khóa + mật khẩu**.

1. Mở PowerShell, chạy (đổi đường dẫn `jbr` nếu bạn cài Android Studio nơi khác):
   ```powershell
   $keytool = "H:\Android\Android Studio\jbr\bin\keytool.exe"
   & $keytool -genkeypair -v `
     -keystore "H:\Tao App Xem Phim\android\vieflix-release.jks" `
     -keyalg RSA -keysize 2048 -validity 10000 `
     -alias vieflix
   ```
2. Nó sẽ hỏi:
   - **Enter keystore password**: đặt 1 mật khẩu (nhớ kỹ!), gõ lại lần nữa.
   - Các câu hỏi tên/tổ chức: gõ gì cũng được (có thể để trống rồi Enter), cuối cùng gõ `yes`.
   - **key password**: bấm Enter để dùng chung mật khẩu keystore.
3. Tạo file `android\key.properties` (copy từ `android\key.properties.example`) và điền:
   ```
   storePassword=<mật khẩu bạn vừa đặt>
   keyPassword=<mật khẩu bạn vừa đặt>
   keyAlias=vieflix
   storeFile=vieflix-release.jks
   ```

> Cả `vieflix-release.jks` và `key.properties` đã được `.gitignore` (không lên git). **Hãy tự
> sao lưu 2 file này ra chỗ an toàn** — mất là không cập nhật đè cho máy đã cài được nữa.

Nếu **chưa** tạo khóa: app vẫn build được nhưng bị ký "debug" (chỉ để thử, không nên phát hành).

---

## C. Build file APK

Đóng app đang chạy (nếu có), rồi:
```powershell
cd "H:\Tao App Xem Phim"
& "H:\flutter\bin\flutter" build apk --release
```
Xong sẽ có file: `build\app\outputs\flutter-apk\app-release.apk` (khoảng 30–60MB).

> Lần đầu build sẽ lâu (Gradle tải phụ thuộc). Các lần sau nhanh hơn.

> **Nếu build báo lỗi "Unable to establish loopback connection":** do biến môi trường `TEMP`
> đang là đường dẫn có tên rút gọn kiểu `C:\Users\WINDFU~1\...`. Khắc phục: tạo `C:\Temp` rồi
> chạy build với `set TEMP=C:\Temp` và `set TMP=C:\Temp` (hoặc trong Git Bash:
> `export TEMP="C:\\Temp"; export TMP="C:\\Temp"`). Toolchain đã ghim AGP 8.7.3 + Gradle 8.10.2 —
> đừng để công cụ nâng lên AGP 9.x vì sẽ vỡ plugin webview.

---

## D. Chép APK lên TV box và cài (sideload)

Chọn **một** trong các cách:

**Cách 1 — USB (dễ nhất):**
1. Chép `app-release.apk` vào USB.
2. Cắm USB vào TV box.
3. Trên TV mở ứng dụng quản lý file (File Manager / X-plore / Send Files to TV...).
4. Mở USB → bấm vào file APK → **Install**. Nếu TV hỏi cho phép cài từ nguồn này → **Cho phép**.

**Cách 2 — "Send files to TV" qua mạng WiFi:**
1. Cài app **Send files to TV** trên cả điện thoại và TV (từ CH Play trên TV).
2. Trên TV chọn *Receive*, trên điện thoại chọn *Send* → gửi file APK (đã chép vào điện thoại).
3. Mở file nhận được trên TV → Install.

**Cách 3 — ADB qua mạng (cho người rành hơn):**
1. Trên TV: bật **Developer options** (vào Cài đặt → About → bấm *Build* 7 lần) → bật
   **USB/Network debugging**. Ghi lại **địa chỉ IP** của TV (Cài đặt → Network).
2. Trên PC:
   ```powershell
   & "H:\Android\Sdk\platform-tools\adb.exe" connect <IP_TV>:5555
   & "H:\Android\Sdk\platform-tools\adb.exe" install -r "H:\Tao App Xem Phim\build\app\outputs\flutter-apk\app-release.apk"
   ```
   `-r` = cài đè (cập nhật) giữ nguyên dữ liệu.

Sau khi cài, mở màn hình chính Android TV → thấy icon **VieFlix** trong hàng ứng dụng.

---

## E. Bật "cập nhật trong app"

Lần đầu bấm nút **Cập nhật** trong app, Android sẽ hỏi cho phép **"Cài ứng dụng không rõ
nguồn gốc"** cho VieFlix → chọn **Cho phép/Allow**. Từ đó về sau, mỗi khi có bản mới:
- App hiện thanh đỏ "Đã có bản cập nhật mới vX.Y.Z".
- Bấm **Cập nhật** → app tự tải APK về → mở trình cài đặt → bấm **Cập nhật/Install** là xong.

(Điều kiện: bản mới phải được phát hành lên GitHub Releases kèm file `.apk` — dùng quy trình
trong skill **release-vieflix**, đã tự động tăng `versionCode`.)

---

## Điều khiển bằng remote (D-pad)
- Dùng phím **mũi tên** để di chuyển; ô/thẻ đang chọn sẽ **sáng viền đỏ + phóng to nhẹ**.
- Bấm **OK (giữa D-pad)** để mở phim/menu.
- Bấm **Back**: ở tab khác sẽ quay về Trang chủ; ở Trang chủ bấm Back nữa để thoát.
- **Tìm kiếm bằng giọng nói**: vào tab *Tìm kiếm*, bấm nút **micro** ở ô tìm rồi nói tên phim.
  (Chỉ hiện khi TV box có dịch vụ nhận giọng nói của Google. Không có thì gõ chữ như thường.)

## Gặp lỗi thường gặp
- **"App not installed" khi cập nhật**: do `versionCode` bản mới không lớn hơn, hoặc APK ký
  khác khóa. Kiểm tra bước 2b của skill release và khóa ở mục B.
- **flutter doctor báo thiếu Android SDK**: chạy lại lệnh `flutter config --android-sdk ...` ở mục A.4.
- **Build lỗi Gradle lần đầu**: thử lại; đảm bảo có mạng để tải phụ thuộc.
