# Bộ công cụ thử app trên Android TV từ máy tính, không phải chạy ra chạy vào.
#
# Cần làm MỘT LẦN trên TV: Cài đặt -> Tuỳ chọn nhà phát triển -> bật "Gỡ lỗi USB"
# (một số box ghi là "ADB debugging" / "Gỡ lỗi qua mạng"). Vào Cài đặt -> Mạng để
# xem địa chỉ IP của TV.
#
#   .\tool\tv.ps1 find                 tìm TV trong mạng LAN (khỏi phải tra IP)
#   .\tool\tv.ps1 connect 192.168.1.50 nối tới TV (nhớ luôn, lần sau khỏi gõ IP)
#   .\tool\tv.ps1 install              cài APK vừa build lên TV
#   .\tool\tv.ps1 run                  mở app
#   .\tool\tv.ps1 log                  xem log app chạy (Ctrl+C để dừng)
#   .\tool\tv.ps1 shot                 chụp màn hình TV về máy
#   .\tool\tv.ps1 key down|ok|back|... bấm nút điều khiển từ xa
#   .\tool\tv.ps1 diag                 cài + mở + gom log lỗi + chụp màn hình
#   .\tool\tv.ps1 crash                chỉ in lỗi/crash gần đây

param(
    [Parameter(Position = 0)][string]$Cmd = 'help',
    [Parameter(Position = 1)][string]$Arg = ''
)

$ErrorActionPreference = 'Stop'
$Adb = 'H:\Android\Sdk\platform-tools\adb.exe'
$Pkg = 'com.vieflix.app_xem_phim'
$Apk = Join-Path $PSScriptRoot '..\build\app\outputs\flutter-apk\app-release.apk'
$IpFile = Join-Path $PSScriptRoot '.tv-ip'
$OutDir = Join-Path $PSScriptRoot '..\build\tv-logs'

# Log của app + mọi thứ liên quan tới phát video. Đây là các tag thực sự có ích:
# AndroidRuntime bắt crash Java, flutter bắt lỗi Dart, mpv/MediaKit bắt trình phát.
$Tags = 'AndroidRuntime:E', 'flutter:V', 'mpv:V', 'MediaKit:V', 'libmpv:V',
        'InAppWebView:V', 'chromium:E', 'ActivityManager:E', 'DEBUG:V', '*:S'

function Get-Ip {
    if ($Arg) { return $Arg }
    if (Test-Path $IpFile) { return (Get-Content $IpFile -Raw).Trim() }
    throw "Chua biet IP cua TV. Chay: .\tool\tv.ps1 connect <IP>  (hoac .\tool\tv.ps1 find)"
}

function Need-Device {
    $d = & $Adb devices | Select-String -Pattern "device$"
    if (-not $d) {
        # Thử nối lại bằng IP đã nhớ — TV hay rớt kết nối sau khi tắt màn hình.
        if (Test-Path $IpFile) {
            $ip = (Get-Content $IpFile -Raw).Trim()
            Write-Host "Chua thay thiet bi, thu noi lai $ip ..." -ForegroundColor Yellow
            & $Adb connect "${ip}:5555" | Out-Null
            Start-Sleep -Seconds 2
            $d = & $Adb devices | Select-String -Pattern "device$"
        }
    }
    if (-not $d) { throw "Khong co thiet bi nao. Chay: .\tool\tv.ps1 connect <IP>" }
}

switch ($Cmd) {

    'find' {
        # Quét dải mạng nội bộ tìm máy mở cổng ADB 5555.
        $local = (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.PrefixOrigin -ne 'WellKnown' -and $_.IPAddress -notlike '169.*' -and $_.IPAddress -ne '127.0.0.1' } |
            Select-Object -First 1).IPAddress
        if (-not $local) { throw "Khong xac dinh duoc dai mang cua may nay" }
        $prefix = $local -replace '\.\d+$', ''
        Write-Host "Quet $prefix.1-254 cong 5555 (khoang 15 giay)..." -ForegroundColor Cyan
        $jobs = 1..254 | ForEach-Object {
            $ip = "$prefix.$_"
            [pscustomobject]@{ Ip = $ip; Task = ([System.Net.Sockets.TcpClient]::new()).ConnectAsync($ip, 5555) }
        }
        Start-Sleep -Seconds 12
        $found = $jobs | Where-Object { $_.Task.Status -eq 'RanToCompletion' }
        if ($found) {
            Write-Host "Tim thay:" -ForegroundColor Green
            $found | ForEach-Object { Write-Host "   $($_.Ip)" }
            Write-Host "Noi bang: .\tool\tv.ps1 connect $($found[0].Ip)"
        } else {
            Write-Host "Khong thay may nao mo cong 5555." -ForegroundColor Yellow
            Write-Host "Kiem tra tren TV: Cai dat -> Tuy chon nha phat trien -> bat 'Go loi USB'."
            Write-Host "May tinh va TV phai CUNG mot mang wifi/lan."
        }
    }

    'connect' {
        $ip = Get-Ip
        & $Adb disconnect | Out-Null
        $r = & $Adb connect "${ip}:5555" 2>&1
        Write-Host $r
        if ($r -match 'connected') {
            Set-Content -Path $IpFile -Value $ip -Encoding utf8
            Write-Host "Da nho IP nay, lan sau khoi go." -ForegroundColor Green
            & $Adb devices -l
            & $Adb shell getprop ro.product.model
            & $Adb shell getprop ro.build.version.release
            & $Adb shell getprop ro.product.cpu.abi
        } else {
            Write-Host "Noi that bai. Tren TV phai bat 'Go loi USB' truoc, va co the TV se hien hop hoi 'Cho phep go loi?' -> chon Cho phep." -ForegroundColor Yellow
        }
    }

    'install' {
        Need-Device
        if (-not (Test-Path $Apk)) { throw "Chua co APK: $Apk  (chay flutter build apk --release truoc)" }
        $mb = [math]::Round((Get-Item $Apk).Length / 1MB, 1)
        Write-Host "Dang cai $mb MB len TV..." -ForegroundColor Cyan
        & $Adb install -r $Apk
    }

    'run' {
        Need-Device
        & $Adb shell monkey -p $Pkg -c android.intent.category.LAUNCHER 1 | Out-Null
        Write-Host "Da mo app tren TV." -ForegroundColor Green
    }

    'stop' { Need-Device; & $Adb shell am force-stop $Pkg; Write-Host "Da dong app." }

    'log' {
        Need-Device
        & $Adb logcat -c
        Write-Host "Dang theo doi log. Thao tac tren TV di, Ctrl+C de dung." -ForegroundColor Cyan
        & $Adb logcat @Tags
    }

    'crash' {
        Need-Device
        Write-Host "--- Loi gan day ---" -ForegroundColor Cyan
        & $Adb logcat -d -t 400 AndroidRuntime:E flutter:E mpv:E MediaKit:E DEBUG:F '*:S'
    }

    'shot' {
        Need-Device
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
        $f = Join-Path $OutDir ("shot-" + (Get-Date -Format 'HHmmss') + ".png")
        & $Adb exec-out screencap -p > $f
        Write-Host "Da luu: $f" -ForegroundColor Green
    }

    'key' {
        Need-Device
        $map = @{
            'up' = 19; 'down' = 20; 'left' = 21; 'right' = 22; 'ok' = 23; 'enter' = 23
            'back' = 4; 'home' = 3; 'menu' = 82; 'play' = 85; 'pause' = 85
            'next' = 87; 'prev' = 88; 'ff' = 90; 'rw' = 89
        }
        if (-not $map.ContainsKey($Arg)) { throw "Nut khong biet: '$Arg'. Co: $($map.Keys -join ', ')" }
        & $Adb shell input keyevent $map[$Arg]
        Write-Host "Da bam: $Arg"
    }

    'diag' {
        # Một phát ăn ngay: cài, mở, chờ, gom log + chụp màn hình.
        Need-Device
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        & $Adb shell am force-stop $Pkg 2>&1 | Out-Null
        if (Test-Path $Apk) {
            Write-Host "Cai APK..." -ForegroundColor Cyan
            & $Adb install -r $Apk
        }
        & $Adb logcat -c
        & $Adb shell monkey -p $Pkg -c android.intent.category.LAUNCHER 1 | Out-Null
        Write-Host "App dang chay. BAY GIO thao tac tren TV (mo phim), roi doi..." -ForegroundColor Yellow
        for ($i = 40; $i -gt 0; $i--) { Write-Progress -Activity "Dang ghi log" -Status "$i giay"; Start-Sleep 1 }
        Write-Progress -Activity "Dang ghi log" -Completed
        $log = Join-Path $OutDir "log-$stamp.txt"
        & $Adb logcat -d @Tags | Out-File -FilePath $log -Encoding utf8
        $shot = Join-Path $OutDir "shot-$stamp.png"
        & $Adb exec-out screencap -p > $shot
        Write-Host "Log:     $log" -ForegroundColor Green
        Write-Host "Anh:     $shot" -ForegroundColor Green
        Write-Host "--- Nhung dong dang chu y ---" -ForegroundColor Cyan
        Select-String -Path $log -Pattern 'Exception|Error|error|FATAL|failed|mpv|MediaKit|m3u8|quang cao|Unable' |
            Select-Object -First 40 | ForEach-Object { $_.Line }
    }

    default {
        # In khối chú thích đầu file làm phần trợ giúp; dừng ở dòng không phải
        # chú thích. Phải đọc bằng UTF8 vì Windows PowerShell 5.1 mặc định đọc
        # theo bảng mã ANSI -> chữ tiếng Việt ra loạn.
        foreach ($l in (Get-Content $PSCommandPath -Encoding UTF8)) {
            if ($l -notmatch '^#') { break }
            Write-Host ($l -replace '^# ?', '')
        }
    }
}
