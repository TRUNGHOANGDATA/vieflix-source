---
name: release-vieflix
description: Build, package, and publish a new VieFlix release (Windows .exe + Android .apk + iPad .ipa) to GitHub Releases, and push the source repo. Use when the user wants to ship/phát hành a new version, bump the version, or đóng gói + đăng bản cập nhật lên GitHub for the movie app in this repo.
---

# Phát hành bản mới VieFlix

Quy trình đầy đủ để ra một bản VieFlix mới: tăng phiên bản → build → đóng gói → đăng GitHub Release. Nhờ đó tính năng **tự cập nhật** trong app hoạt động (app đọc release mới nhất của repo và báo người dùng).

**Bối cảnh cố định:**
- Thư mục dự án: `H:\Tao App Xem Phim`
- Flutter: `H:/flutter/bin/flutter`
- Repo release (public): `TRUNGHOANGDATA/vieflix`
- Exe sau build: `build/windows/x64/runner/Release/VieFlix.exe`
- APK sau build: `build/app/outputs/flutter-apk/app-release.apk`
- Phiên bản app nằm ở hằng `kAppVersion` trong `lib/data/update_checker.dart`
- `gh` CLI: `C:\Program Files\GitHub CLI\gh.exe` — dùng để đăng release + upload file, xem Bước 5. **ĐÃ đăng nhập** (tài khoản `TRUNGHOANGDATA`, lưu ở keyring; xác nhận 04/10/2026). Vẫn chạy `gh auth status` một lần cho chắc.
- Repo SOURCE (private): `TRUNGHOANGDATA/vieflix-source` = `origin` của thư mục dự án. Mỗi bản phải **commit + push** lên đây (Bước 2b) — bản iOS build từ chính repo này.
- **Mỗi bản phát hành làm đủ 3 nền tảng**: Windows (bộ cài .exe), Android/TV (.apk), iPad (.ipa — Bước 3c). User đã chốt điều này từ bản 1.0.57.
- Biến `TMDB_KEY` (khóa TMDB nhúng lúc build qua `--dart-define`) KHÔNG có trên máy → bản Windows/APK build không kèm khóa, user tự nhập ở Cài đặt. Bình thường, đừng chặn phát hành vì nó. (Bản iOS lấy từ secret `TMDB_KEY` của repo source nếu có.)
- ⚠️ Chạy `flutter` bằng **Bash tool**, KHÔNG dùng PowerShell `& "H:/flutter/bin/flutter" ... | ...` — PowerShell báo "Cannot run a document in the middle of a pipeline" và KHÔNG build gì; bước ISCC sau đó vẫn "thành công" nhưng đóng gói bản build CŨ (đã dính ở 1.0.57).
- **3 chỗ phải bump cùng lúc mỗi bản**: `kAppVersion`, `version:` trong `pubspec.yaml`, `#define MyAppVersion` trong `installer/VieFlix.iss`. Sót một chỗ là app tự báo có bản mới cho chính nó, hoặc Android từ chối cài đè.
- **Mỗi release đăng CẢ BA file**: bộ cài Windows `VieFlix-Setup-vX.Y.Z.exe`, Android `VieFlix-TV.apk`, iPad `VieFlix-vX.Y.Z.ipa`. App tự cập nhật chọn đúng file theo nền tảng đang chạy (.exe cho Windows, .apk cho Android; bỏ qua .ipa — iOS không tự cập nhật, user cài lại bằng AltStore).
- ⚠️ **APK PHẢI đặt tên đúng `VieFlix-TV.apk`** (KHÔNG kèm số phiên bản) để link tải cố định luôn trỏ bản mới nhất:
  `https://github.com/TRUNGHOANGDATA/vieflix/releases/latest/download/VieFlix-TV.apk`
  Link ngắn user dùng trên app Downloader của TV: **`tinyurl.com/23h3geuo`** (đã tạo, trỏ vào link trên — không cần tạo lại mỗi bản).
- Khóa ký APK CỐ ĐỊNH: `android/vieflix-release.jks` + `android/key.properties` (KHÔNG đổi khóa giữa các bản, nếu không Android từ chối cập nhật đè). Xem `docs/ANDROID_TV.md`.

## Các bước

### 1. Hỏi/xác định số phiên bản mới
Xem `kAppVersion` hiện tại trong `lib/data/update_checker.dart`. Bản mới phải LỚN hơn (vd 1.0.1 → 1.0.2). Nếu user không nói rõ, tăng số cuối 1 đơn vị.

### 2. Tăng `kAppVersion` VÀ phiên bản Android
a) Sửa `lib/data/update_checker.dart`: `const String kAppVersion = 'X.Y.Z';` cho khớp tag sẽ đăng. **Bắt buộc** — nếu quên, app mới sẽ tự báo "có bản cập nhật" chính nó.

b) Sửa `pubspec.yaml` dòng `version:` thành `X.Y.Z+<versionCode>`. **`versionCode` PHẢI tăng dần mỗi bản**, nếu không Android sẽ báo "App not installed" khi cập nhật đè. Dùng công thức đơn giản để luôn tăng: `versionCode = X*10000 + Y*100 + Z`.
- Ví dụ 1.0.2 → `version: 1.0.2+10002`; 1.1.0 → `version: 1.1.0+10100`.

c) Sửa `installer/VieFlix.iss`: `#define MyAppVersion "X.Y.Z"`.

### 2b. Commit + push lên repo source (TRƯỚC khi build iOS)
Nếu còn thay đổi code chưa commit (bản sửa của bản này) thì commit riêng trước, rồi commit phần tăng phiên bản theo mẫu đã dùng:
```bash
cd "H:/Tao App Xem Phim"
git add installer/VieFlix.iss lib/data/update_checker.dart pubspec.yaml
git commit -m "chore(release): X.Y.Z — bump kAppVersion/pubspec/installer" -m "<tóm tắt bản này>"
git push origin master
```
`notes.md` (ghi chú phát hành) để untracked, KHÔNG commit. File `.ipa`/`.apk` ở gốc repo cũng không đưa vào git.

Push xong thì **kích build iOS ngay** (Bước 3c) để nó chạy song song trong lúc build Windows/APK.

### 3. Đóng app đang chạy rồi build
Phải đóng VieFlix.exe trước, nếu không nó khoá `WebView2Loader.dll` làm build lỗi.
```bash
# PowerShell:
Get-Process -Name VieFlix -ErrorAction SilentlyContinue | Stop-Process -Force
# rồi:
cd "H:/Tao App Xem Phim" && "H:/flutter/bin/flutter" build windows --release
```
Xác nhận có dòng `√ Built ...VieFlix.exe`.

### 3b. Build APK cho Android TV
Cần Android SDK đã cài (xem `docs/ANDROID_TV.md`) và khóa ký cố định `android/key.properties` phải tồn tại.

⚠️ **BẮT BUỘC đặt môi trường trước khi build APK** (nếu không sẽ lỗi):
- `JAVA_HOME=H:/Android/jdk17/jdk-17.0.20+8` (JDK 17 đã cài off-C).
- `ANDROID_SDK_ROOT=H:/Android/Sdk`.
- `TEMP=C:\Temp` và `TMP=C:\Temp` — **RẤT QUAN TRỌNG**. Nếu TEMP là đường dẫn có tên rút gọn 8.3
  (vd `C:\Users\WINDFU~1\...`), Java NIO tạo self-pipe qua AF_UNIX autobind bị lỗi
  *"Unable to establish loopback connection / Invalid argument: connect"* → Gradle chết.
  Đặt TEMP về đường dẫn sạch (`C:\Temp`, `mkdir C:\Temp` trước) là hết.
- Toolchain đã ghim ở `android/settings.gradle.kts`: **AGP 8.7.3 + Kotlin 2.1.10**, Gradle wrapper
  **8.10.2**. (Template Flutter mặc định AGP 9.0.1/Gradle 9.1 làm `flutter_inappwebview 1.1.3` vỡ vì
  cấm `proguard-android.txt` — ĐỪNG nâng lại lên 9.x.) Khóa ký resolve bằng `rootProject.file(...)`
  nên `storeFile=vieflix-release.jks` (đặt ở `android/`).
```bash
export JAVA_HOME="H:/Android/jdk17/jdk-17.0.20+8"
export ANDROID_SDK_ROOT="H:/Android/Sdk"
mkdir -p /c/Temp; export TEMP="C:\\Temp"; export TMP="C:\\Temp"
cd "H:/Tao App Xem Phim" && "H:/flutter/bin/flutter" build apk --release
```
**APK CHỈ chứa thư viện ARM** (`arm64-v8a` + `armeabi-v7a`), cấu hình ở
`android/app/build.gradle.kts` mục `packaging { jniLibs { excludes } }`. Từ 1.0.26
trình phát native bật cả trên Android nên libmpv.so chiếm phần lớn APK — riêng bản
x86_64 là 34.6MB, đưa APK từ 58.8MB lên 93.4MB mà chẳng TV box nào dùng tới.
Lưu ý `ndk { abiFilters }` KHÔNG ăn (plugin Flutter ghi đè) và `--target-platform`
chỉ lọc thư viện của Flutter chứ không lọc .so trong AAR của plugin — nên phải loại
lúc đóng gói. Cần chạy máy ảo Android thì tạm bỏ khối `packaging` đó.
Kiểm nhanh sau khi build: `aapt2 dump badging <apk> | grep native-code` phải ra
đúng `'arm64-v8a' 'armeabi-v7a'`.

Ra file `build/app/outputs/flutter-apk/app-release.apk`. Chép ra tên theo phiên bản:
```powershell
$ver = "X.Y.Z"   # <-- đổi cho khớp
Copy-Item "H:\Tao App Xem Phim\build\app\outputs\flutter-apk\app-release.apk" "H:\Tao App Xem Phim\VieFlix-v$ver.apk" -Force
```
**Kiểm APK trước khi đăng** (2 lệnh này thực sự kiểm được, khác với cách cũ chỉ grep log build — log không hề nói APK ký bằng khóa nào):
```bash
bt=$(ls -d H:/Android/Sdk/build-tools/*/ | tail -1)
# 1. versionCode PHẢI tăng so với bản trước, versionName khớp kAppVersion
"${bt}aapt2.exe" dump badging build/app/outputs/flutter-apk/app-release.apk | grep -E "^package"
# 2. Chữ ký PHẢI là CN=VieFlix, SHA-256 5068a120db147c8e7dc85f6b69c517d0f607e0dffe2fd1896d443ef21df2b758
JAVA_HOME="H:/Android/jdk17/jdk-17.0.20+8" "${bt}apksigner.bat" verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk | grep "SHA-256 digest"
```
⚠️ ĐỪNG dùng `keytool -printcert -jarfile` để kiểm — APK ký theo scheme v2/v3 (không còn chữ ký JAR v1) nên keytool **không in ra gì**, dễ tưởng là APK hỏng.

Nếu SHA-256 khác dòng trên → APK bị ký khóa khác (hoặc ký debug do thiếu `android/key.properties`) → Android **từ chối cập nhật đè**, user phải gỡ app cũ. Phải sửa khóa trước khi đăng (docs/ANDROID_TV.md).

Sau khi kiểm xong, chép ra đúng tên đăng: `cp -f build/app/outputs/flutter-apk/app-release.apk VieFlix-TV.apk`.

### 3c. Build .ipa cho iPad (GitHub Actions, máy macOS miễn phí)
Không có Mac → build trên workflow `Build iOS IPA` (`.github/workflows/ios.yml`) của repo SOURCE. Nó build `--no-codesign`, cắt binary fat về arm64, ad-hoc ký lại, gói .ipa bằng `ditto` — để AltStore ký đè được (chi tiết lý do nằm trong chú thích của file workflow, ĐỪNG bỏ bước nào). Mất ~5 phút.
```bash
gh="C:/Program Files/GitHub CLI/gh.exe"
# PHẢI push master trước (Bước 2b) — workflow build đúng commit đang ở master trên GitHub.
"$gh" workflow run "Build iOS IPA" --repo TRUNGHOANGDATA/vieflix-source --ref master
"$gh" run list --repo TRUNGHOANGDATA/vieflix-source --workflow "Build iOS IPA" --limit 1   # lấy <id>
"$gh" run view <id> --repo TRUNGHOANGDATA/vieflix-source --json status,conclusion,headSha
# xong (completed success, headSha = commit vừa push) thì tải về:
"$gh" run download <id> --repo TRUNGHOANGDATA/vieflix-source -n VieFlix-ios-ipa -D <thư mục tạm>
cp -f "<thư mục tạm>/VieFlix.ipa" "H:/Tao App Xem Phim/VieFlix-vX.Y.Z.ipa"
```
(Đẩy tag `v*` lên repo source cũng tự kích workflow này, nhưng cách chạy tay ở trên là cách đã dùng.)

**Kiểm .ipa** — phiên bản bên trong phải khớp:
```bash
python -c "import zipfile,plistlib; z=zipfile.ZipFile(r'H:/Tao App Xem Phim/VieFlix-vX.Y.Z.ipa'); p=plistlib.loads(z.read('Payload/Runner.app/Info.plist')); print(p['CFBundleShortVersionString'], p['CFBundleVersion'])"
```
Phải ra `X.Y.Z <versionCode>`. User cài lên iPad bằng AltStore (AltServer trên Windows).

### 4. Đóng gói zip — THỰC TẾ KHÔNG CÒN DÙNG
Từ 1.0.3 trở đi mỗi release chỉ đăng **bộ cài `.exe` + `.apk`** (xem mục "Tạo bộ cài" ở dưới — mục đó ghi "tùy chọn" nhưng thực tế nó là cách chính). Bản 1.0.15 và 1.0.16 đều KHÔNG có zip. Giữ phần dưới đây làm dự phòng nếu cần gói không-cài-đặt.

<details><summary>Cách đóng zip (dự phòng)</summary>

#### Đóng gói zip (LOẠI thư mục cache WebView2)
Thư mục `VieFlix.exe.WebView2` (~80MB, sinh ra khi chạy app) KHÔNG được cho vào zip.
**Đặt tên file zip THEO PHIÊN BẢN** (`VieFlix-vX.Y.Z.zip`) để user khỏi nhầm — thay `X.Y.Z` cho khớp bản đang đóng.
```powershell
$ver = "X.Y.Z"   # <-- đổi cho khớp phiên bản
$rel = "H:\Tao App Xem Phim\build\windows\x64\runner\Release"
$out = "H:\Tao App Xem Phim\VieFlix-v$ver.zip"
$stage = "H:\Tao App Xem Phim\_stage_zip"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage | Out-Null
Get-ChildItem $rel | Where-Object { $_.Name -ne 'VieFlix.exe.WebView2' } | Copy-Item -Destination $stage -Recurse -Force
if (Test-Path $out) { Remove-Item $out -Force }
Compress-Archive -Path "$stage\*" -DestinationPath $out -CompressionLevel Optimal
Remove-Item $stage -Recurse -Force
```
Gói ~12–13MB. Gửi cho user bằng SendUserFile. (App tự cập nhật chọn asset đầu tiên có đuôi `.zip`, nên tên có kèm phiên bản vẫn hoạt động bình thường.)

</details>

### 5. Đăng GitHub Release + upload file

**Cách chính: `gh` CLI — một lệnh, upload được cả file lớn.**

`gh` đã cài sẵn trên máy (19/08/2026, bản 2.97.0) tại `C:\Program Files\GitHub CLI\gh.exe`.
`gh` KHÔNG bị giới hạn 10MB như công cụ `file_upload` của Claude, nên Claude tự đăng được trọn gói.

```bash
gh="C:/Program Files/GitHub CLI/gh.exe"
"$gh" release create vX.Y.Z \
  --repo TRUNGHOANGDATA/vieflix \
  --title "VieFlix vX.Y.Z" \
  --notes-file notes.md \
  "installer/VieFlix-Setup-vX.Y.Z.exe" \
  "VieFlix-TV.apk" \
  "VieFlix-vX.Y.Z.ipa"
```
`gh release create` tự tạo tag trên repo đó, nên không gặp lỗi "tag name can't be blank" của giao diện web.

⚠️ **Kiểm `gh auth status` TRƯỚC.** Nếu chưa đăng nhập thì **phải nhờ user chạy `gh auth login`** (chọn GitHub.com → HTTPS → Yes → Login with a web browser). Claude KHÔNG được nhập tài khoản/token hộ user, và `gh auth login` là lệnh hỏi-đáp tương tác nên môi trường của Claude cũng không chạy được. Tính tới 04/10/2026 **đã đăng nhập** (bản 1.0.57 đăng bằng `gh`) — chỉ khi `gh auth status` báo lỗi mới phải nhờ user.

**Cách dự phòng: user tự đăng bằng trình duyệt.**
Dùng khi `gh` chưa đăng nhập. (Đã thử điều khiển Chrome qua `claude-in-chrome` ngày 19/08/2026 — extension báo *not connected*, nên đừng mặc định trông vào đường này.) Đưa user link + nội dung sẵn để dán:
1. `https://github.com/TRUNGHOANGDATA/vieflix/releases/new`
2. Dropdown **Select tag** → gõ `vX.Y.Z` → **Create new tag** → **bấm nút Create trong hộp thoại** (RẤT DỄ SÓT — thiếu nó Publish báo lỗi "tag name can't be blank").
3. **Title**: `VieFlix vX.Y.Z`; dán ghi chú vào ô mô tả.
4. Đính **CẢ BA** file ở khung *Attach binaries* → đợi 100% → **Publish release**.

### 6. Kiểm lại sau khi đăng (BẮT BUỘC)
Đăng xong phải xác nhận bằng API, đừng tin vào cảm giác:
```bash
curl -s "https://api.github.com/repos/TRUNGHOANGDATA/vieflix/releases/latest" \
  | grep -E '"tag_name"|"name":'
# Link cố định cho TV phải redirect sang đúng tag mới:
curl -s -o /dev/null -w "%{http_code} -> %{redirect_url}\n" \
  "https://github.com/TRUNGHOANGDATA/vieflix/releases/latest/download/VieFlix-TV.apk"
```
Phải thấy đủ **3 asset** (`VieFlix-Setup-vX.Y.Z.exe` + `VieFlix-TV.apk` + `VieFlix-vX.Y.Z.ipa`) và link trên trả về `302` trỏ vào tag mới.

Nếu release đã publish mà CHƯA kèm file: app không lỗi (updater rơi về mở trang release — xem `update_checker.dart`), nhưng user bấm "Cập nhật" sẽ thấy trang trống. Đính file càng sớm càng tốt.

App tự cập nhật chọn `.apk` khi chạy Android, `.exe` (bộ cài) khi chạy Windows; iOS không tự cập nhật (bỏ qua .ipa).

## Tạo bộ cài đặt VieFlix-Setup.exe — ĐÂY LÀ CÁCH CHÍNH cho Windows
Nếu user muốn "bộ cài như phần mềm thật" (wizard, shortcut Desktop/Start Menu, gỡ trong Add/Remove Programs) thì dùng **Inno Setup** thay vì zip.
- Trình biên dịch: `C:\Users\WINDFURY1010\AppData\Local\Programs\Inno Setup 6\ISCC.exe` (đã cài sẵn qua winget id `JRSoftware.InnoSetup`).
- Script: `installer\VieFlix.iss` (đã có sẵn, wizard tiếng Việt, icon `windows\runner\resources\app_icon.ico`).
- **Trước khi build lại**: `#define MyAppVersion` trong `installer\VieFlix.iss` phải khớp `kAppVersion` (đã làm ở Bước 2c).
- Build (sau khi đã `flutter build windows --release` ở bước 3):
```bash
cd "H:/Tao App Xem Phim/installer" && "/c/Users/WINDFURY1010/AppData/Local/Programs/Inno Setup 6/ISCC.exe" VieFlix.iss
```
- Ra file `installer\VieFlix-Setup-vX.Y.Z.exe` (~26MB ở bản 1.0.57). Script tự loại thư mục cache `*.WebView2`. Gửi user bằng SendUserFile.
- **CÀI PER-USER (không admin):** `PrivilegesRequired=lowest` → cài vào `{localappdata}\Programs\VieFlix`, KHÔNG hiện UAC. Đây là điều kiện để **tự cập nhật im lặng** (xem dưới).

### TỰ CẬP NHẬT WINDOWS (một chạm, im lặng) — QUAN TRỌNG
Từ v1.0.3, app Windows **tự tải + tự cài** bản mới:
- `update_checker.dart`: `check()` ưu tiên asset đuôi **`.exe`** (bộ cài) → `UpdateInfo.isInstaller=true`. `downloadInstaller()` tải bộ cài về `%TEMP%`, `runWindowsInstaller()` chạy nó với cờ `/SILENT /SUPPRESSMSGBOXES /NOCANCEL /FORCECLOSEAPPLICATIONS` rồi `exit(0)` để mở khoá file.
- Bộ cài (`VieFlix.iss`) có `CloseApplications=yes` + mục `[Run] ... Check: WizardSilent` để tự đóng app cũ và mở lại app sau khi ghi đè.
- **=> Mỗi release Windows PHẢI đính bộ cài `VieFlix-Setup-vX.Y.Z.exe`** thì nút mới thành "Cập nhật ngay" (tự cài). Nếu chỉ đính `.zip`, nút chỉ "Tải về" (mở link, user tự cài).
- Nếu đính CẢ .exe lẫn .zip: updater chọn `.exe` trước → vẫn tự cài. An toàn.
- Đã test thật 2026-08-08: chạy bộ cài đè lúc app đang mở → tự đóng (pid cũ mất) + mở lại (pid mới). OK.

## Lưu ý
- Repo `vieflix` là public, chỉ chứa bản tải (không phải source) — nên GitHub API `releases/latest` đọc được mà không cần token.
- Nếu build lỗi "Nuget is not installed": cần `nuget.exe` trong `H:\flutter\bin` (đã có sẵn). Sau khi đổi PATH phải `flutter clean`.
- Đổi tên file exe (BINARY_NAME trong windows/CMakeLists.txt) thì phải `flutter clean` trước khi build (CMake cache tên cũ).
