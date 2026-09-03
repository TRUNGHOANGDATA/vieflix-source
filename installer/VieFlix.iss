; ============================================================
;  Bộ cài đặt VieFlix (Inno Setup)
;  Biên dịch: chạy build\... release trước, rồi ISCC installer\VieFlix.iss
; ============================================================

#define MyAppName "VieFlix"
#define MyAppVersion "1.0.41"
#define MyAppPublisher "VieFlix"
#define MyAppExeName "VieFlix.exe"
; Thư mục chứa file đã build (đường dẫn tương đối tính từ file .iss này)
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
; AppId cố định để nâng cấp đè lên bản cũ (đừng đổi giữa các phiên bản)
AppId={{B8F3A1C2-9D4E-4F6A-8B21-7C5E9A0D1F34}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; CÀI CHO NGƯỜI DÙNG HIỆN TẠI (không cần admin) -> tự cập nhật im lặng KHÔNG hiện
; hộp thoại UAC. {autopf} khi 'lowest' trỏ về {localappdata}\Programs (thư mục user
; ghi được), nên trình cài luôn ghi đè được lúc tự cập nhật.
PrivilegesRequired=lowest
OutputDir=.
OutputBaseFilename=VieFlix-Setup-v{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Cho phép tính năng TỰ CẬP NHẬT: khi chạy im lặng (/SILENT), tự đóng VieFlix đang
; chạy để ghi đè file, rồi mục [Run] bên dưới sẽ mở lại app.
CloseApplications=yes
RestartApplications=no
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "vi"; MessagesFile: "compiler:Default.isl"

; ---- Chữ tiếng Việt cho wizard (đè lên bản English mặc định) ----
[Messages]
SetupWindowTitle=Cài đặt - %1
SetupAppTitle=Cài đặt
WelcomeLabel1=Chào mừng cài đặt [name]
WelcomeLabel2=Trình này sẽ cài [name/ver] vào máy của bạn.%n%nKhuyên bạn đóng các ứng dụng khác trước khi tiếp tục.
ClickNext=Bấm Tiếp tục để đi tiếp, hoặc Hủy để thoát.
ButtonBack=< &Quay lại
ButtonNext=&Tiếp tục >
ButtonInstall=&Cài đặt
ButtonCancel=Hủy
ButtonFinish=&Hoàn tất
ButtonBrowse=&Chọn thư mục...
ButtonWizardBrowse=Chọn th&ư mục...
SelectDirDesc=Bạn muốn cài [name] vào đâu?
SelectDirLabel3=Trình cài đặt sẽ đặt [name] vào thư mục dưới đây.
SelectDirBrowseLabel=Bấm Tiếp tục để dùng thư mục này. Muốn đổi thì bấm Chọn thư mục.
DiskSpaceGBLabel=Cần ít nhất [gb] GB trống.
DiskSpaceMBLabel=Cần ít nhất [mb] MB trống.
SelectTasksDesc=Bạn muốn thực hiện thêm việc gì?
SelectTasksLabel2=Chọn các mục bổ sung rồi bấm Tiếp tục.
ReadyLabel1=Trình cài đặt đã sẵn sàng cài [name] vào máy bạn.
ReadyLabel2a=Bấm Cài đặt để bắt đầu, hoặc Quay lại để xem/chỉnh lại.
WizardInstalling=Đang cài đặt
InstallingLabel=Vui lòng đợi trong khi [name] được cài vào máy...
WizardPreparing=Đang chuẩn bị
PreparingDesc=Đang chuẩn bị cài [name] vào máy bạn.
StatusExtractFiles=Đang giải nén tập tin...
FinishedHeadingLabel=Hoàn tất cài đặt [name]
FinishedLabelNoIcons=Đã cài xong [name] trên máy bạn.
FinishedLabel=Đã cài xong [name] trên máy bạn. Có thể mở app bằng biểu tượng vừa tạo.
ClickFinish=Bấm Hoàn tất để thoát.
RunEntryExec=Mở %1
ConfirmUninstall=Bạn có chắc muốn gỡ bỏ hoàn toàn %1 khỏi máy?
UninstallStatusLabel=Vui lòng đợi trong khi %1 được gỡ khỏi máy...

[CustomMessages]
vi.CreateDesktopIcon=Tạo biểu tượng ngoài màn hình (Desktop)
vi.LaunchApp=Mở VieFlix ngay bây giờ
vi.AdditionalIcons=Biểu tượng bổ sung:

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Copy toàn bộ thư mục Release NHƯNG loại thư mục cache WebView2 (sinh ra khi chạy app)
Source: "{#ReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Excludes: "{#MyAppExeName},*.WebView2"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Gỡ cài đặt {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Cài thường: hiện ô tick "Mở VieFlix ngay" ở bước cuối.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchApp}"; Flags: nowait postinstall skipifsilent
; Cài im lặng (tự cập nhật): tự mở lại app sau khi ghi đè xong.
Filename: "{app}\{#MyAppExeName}"; Flags: nowait; Check: WizardSilent

[UninstallDelete]
; Xoá luôn cache WebView2 do app tạo ra khi gỡ cài
Type: filesandordirs; Name: "{app}\{#MyAppExeName}.WebView2"
