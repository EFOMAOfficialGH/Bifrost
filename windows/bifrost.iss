#define MyAppName "Bifrost"
#define MyAppPublisher "EFOMA"
#define MyAppExeName "bifrost.exe"

[Setup]
AppId={{2EBC16EA-0E2F-4D82-A83D-4D04698C93A3}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Bifrost
DefaultGroupName=Bifrost
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=Bifrost-Windows-Installer
SetupIconFile=runner\resources\app_icon.ico
WizardSmallImageFile=..\assets\icon.png
WizardSmallImageBackColor=#040F28
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
PrivilegesRequired=admin
CloseApplications=force
CloseApplicationsFilter={#MyAppExeName}
RestartApplications=no
WizardStyle=modern zircon
WizardSizePercent=100,100
Compression=lzma2
SolidCompression=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: checkedonce
Name: "startmenushortcut"; Description: "Create a Start-menu shortcut"; GroupDescription: "Shortcuts:"; Flags: checkedonce

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Bifrost"; Filename: "{app}\{#MyAppExeName}"; Tasks: startmenushortcut
Name: "{autodesktop}\Bifrost"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCR; Subkey: "*\shell\Send with Bifrost"; ValueType: string; ValueName: ""; ValueData: "Send with Bifrost"; Flags: uninsdeletekey
Root: HKCR; Subkey: "*\shell\Send with Bifrost\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Run Bifrost"; Flags: postinstall nowait skipifsilent; Check: ShouldShowRunBifrost

[Code]
var
  WasBifrostRunning: Boolean;

function ShouldShowRunBifrost: Boolean;
begin
  Result := not WasBifrostRunning;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if (CurStep = ssInstall) and FileExists(ExpandConstant('{app}\{#MyAppExeName}')) then
  begin
    if Exec(ExpandConstant('{app}\{#MyAppExeName}'), '--installer-shutdown', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      WasBifrostRunning := ResultCode <> 0;
  end
  else if (CurStep = ssPostInstall) and WasBifrostRunning then
  begin
    Exec(ExpandConstant('{app}\{#MyAppExeName}'), '', ExpandConstant('{app}'), SW_SHOWNORMAL, ewNoWait, ResultCode);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    if FileExists(ExpandConstant('{app}\{#MyAppExeName}')) then
      Exec(ExpandConstant('{app}\{#MyAppExeName}'), '--installer-shutdown', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode);
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Bifrost');
  end;
end;
