unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.AppEvnts, Vcl.ExtCtrls, Vcl.Menus, Registry,
  IniFiles, Vcl.ComCtrls, Vcl.StdCtrls,
  Execute.Managers, Execute.DesktopDuplicationAPI;

type
  TfrmMain = class(TForm)
    ApplicationEvents1: TApplicationEvents;
    TrayIcon1: TTrayIcon;
    PopupMenu1: TPopupMenu;
    mnuShow: TMenuItem;
    mnuExit: TMenuItem;
    N2: TMenuItem;
    gbOpacity: TGroupBox;
    tbOpacity: TTrackBar;
    mnuEnabled: TMenuItem;
    N1: TMenuItem;
    chkEnabled: TCheckBox;
    mnuAutoRun: TMenuItem;
    btnShowForms: TButton;
    tbOffset: TTrackBar;
    chkPause: TCheckBox;
    mnuPause: TMenuItem;
    procedure ApplicationEvents1Minimize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TrayIcon1DblClick(Sender: TObject);
    procedure mnuShowClick(Sender: TObject);
    procedure mnuExitClick(Sender: TObject);
    procedure mnuEnabledClick(Sender: TObject);
    procedure tbOpacityChange(Sender: TObject);
    procedure chkEnabledClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure mnuAutoRunClick(Sender: TObject);
    procedure btnShowFormsClick(Sender: TObject);
    procedure tbOpacityKeyPress(Sender: TObject; var Key: Char);
    procedure tbOffsetChange(Sender: TObject);
    procedure chkPauseClick(Sender: TObject);
    procedure mnuPauseClick(Sender: TObject);
  private
    FDisplayChanging: Boolean;
    procedure WMDisplayChange(var Message: TWMDisplayChange); message WM_DISPLAYCHANGE;
    function isSystemAlive: Boolean;
    procedure CheckDisplayChanged;
  private
    FIsNeedRecapture: Boolean; // TRUE = end Thread capturing
    FCaptureList: TExecuteList;
    FScreenList: TScreenList;
    procedure recreateScreenList;
    procedure recreateCaptures;
    function OnCheckIfNeedRecapture: Boolean;
  private
    { Private declarations }
    Ini: TIniFile;
    FBrightnessEnabled: Boolean;
    FPaused: Boolean;
    FOpacity: Integer;
    FMinOffset: Integer;
    FHintAlready: Boolean;
    FIsExit: Boolean;

    procedure CheckAndFixMainPositionIfOutOfScope();
    procedure ShowMainAtCenter(ShowIt: Boolean = False);
    procedure UpdateLabels;
    procedure SetOpacity(const Val: Integer);
    procedure SetHintAlready;
    { minimum offset }
    procedure SetOffset(const Val: Integer);

    function getBEnabled: Boolean;
    procedure setBEnabled(const Value: Boolean);
    function getPaused: Boolean;
    procedure setPaused(const Value: Boolean);

    property BrightnessEnabled: Boolean read getBEnabled write setBEnabled;
    property Paused: Boolean read getPaused write setPaused;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

function GetAutoStart(AppTitle: string): Boolean;
const
  RegKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  // or: RegKey = 'Software\Microsoft\Windows\CurrentVersion\RunOnce';
var
  Registry: TRegistry;
begin
  Result := False;
  Registry := TRegistry.Create(KEY_READ);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    // HKEY_LOCAL_MACHINE //a bit hard

    if Registry.OpenKey(RegKey, False) then
    begin
      Result := Registry.ValueExists(AppTitle);
      Registry.CloseKey;
    end;
  finally
    Registry.Free;
  end;
end;

procedure SetAutoStart(AppName, AppTitle: string; bRegister: Boolean);
const
  RegKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  // or: RegKey = 'Software\Microsoft\Windows\CurrentVersion\RunOnce';
var
  Registry: TRegistry;
begin
  Registry := TRegistry.Create(KEY_SET_VALUE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    // HKEY_LOCAL_MACHINE //a bit hard

    if Registry.OpenKey(RegKey, False) then
    begin
      if bRegister = False then
        Registry.DeleteValue(AppTitle)
      else
        Registry.WriteString(AppTitle, AppName);
      Registry.CloseKey;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TfrmMain.ApplicationEvents1Minimize(Sender: TObject);
begin
//  { Main hide show hint? }
  if not FHintAlready and frmMain.Visible then
  begin
    SetHintAlready;
    TrayIcon1.ShowBalloonHint;
  end;
  { Hide the window and set its state variable to wsMinimized. }
  Hide();
  WindowState := wsMinimized;

//  { Show the animated tray icon and also a hint balloon. }
//  //if not TrayIcon1.Visible then
//  TrayIcon1.Visible := True;
////  TrayIcon1.Animate := True;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if not FIsExit then
  begin
    { just wants to minimize the app }
    Application.Minimize;
    Action := TCloseAction.caNone;
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
//var
//  MyIcon : TIcon;
begin
  FCaptureList := TExecuteList.Create;
  FScreenList := TScreenList.Create;
  mnuAutoRun.Checked := GetAutoStart('Cuyo Brightness');
  { Load the tray icons. }
//  TrayIcon1.Icons := TImageList.Create(Self);
//  MyIcon := TIcon.Create;
//  MyIcon.LoadFromFile('icons/earth1.ico');
  TrayIcon1.Icon.Assign(frmMain.Icon);
//  TrayIcon1.Icons.AddIcon(frmMain.Icon);

//  MyIcon.LoadFromFile('icons/earth2.ico');
//  TrayIcon1.Icons.AddIcon(MyIcon);
//  MyIcon.LoadFromFile('icons/earth3.ico');
//  TrayIcon1.Icons.AddIcon(MyIcon);
//  MyIcon.LoadFromFile('icons/earth4.ico');
//  TrayIcon1.Icons.AddIcon(MyIcon);

  { Set up a hint message and the animation interval. }
  TrayIcon1.Hint := frmMain.Caption; //'Hello World!';
//  TrayIcon1.AnimateInterval := 200;

  { Set up a hint balloon. }
  TrayIcon1.BalloonTitle := frmMain.Caption + ' setting.';
  TrayIcon1.BalloonHint :=
    'Double click the system tray icon to restore the window.';
  TrayIcon1.BalloonFlags := bfInfo;

  // load defaults
  TrayIcon1.Visible := True; // always showing now
  SetOpacity(50);
  SetOffset(0);
  SetPaused(False);

  // load settings
  Ini := TIniFile.Create( ChangeFileExt( Application.ExeName, '.INI' ) );
  try
    if Ini.SectionExists('Form') and Ini.ValueExists('Form', 'Top') and Ini.ValueExists('Form', 'Left') then
    begin
      Application.ShowMainForm := False;
      if Ini.ReadBool('Form', 'Debug', False) then
        btnShowForms.Visible := True;
      Top := Ini.ReadInteger('Form', 'Top', 0);
      Left := Ini.ReadInteger('Form', 'Left', 0);
      SetOpacity(Ini.ReadInteger('Form', 'BrightNessTarget', FOpacity));
      SetOffset(Ini.ReadInteger('Form', 'BrightNessTargetMinOffset', FMinOffset));
      setBEnabled(Ini.ReadBool('Form', 'BrightnessEnabled', FBrightnessEnabled));
      setPaused(Ini.ReadBool('Form', 'Paused', FPaused));
      FHintAlready := Ini.ReadBool('Form', 'HintAlready', False);
      Left := Ini.ReadInteger('Form', 'Left', 0);
    end else
    begin
      Application.ShowMainForm := True;
      // show at middle
      ShowMainAtCenter(True);
    end;
  finally
    Ini.Free;
  end;
  recreateCaptures();
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  Ini := TIniFile.Create( ChangeFileExt( Application.ExeName, '.INI' ) );
  try
    Ini.WriteInteger('Form', 'Top', frmMain.Top);
    Ini.WriteInteger('Form', 'Left', frmMain.Left);
    Ini.WriteInteger('Form', 'BrightNessTarget', FOpacity);
    Ini.WriteInteger('Form', 'BrightNessTargetMinOffset', FMinOffset);
    Ini.WriteBool('Form', 'BrightnessEnabled', FBrightnessEnabled);
    Ini.WriteBool('Form', 'Paused', FPaused);
  finally
    Ini.Free;
  end;
  FIsNeedRecapture := True;
  FCaptureList.KillThreads;
  FreeAndNil(FCaptureList); //FCaptureList.Free;
  FreeAndNil(FScreenList); //FScreenList.Free;
end;

function TfrmMain.getBEnabled: Boolean;
begin
  result := FBrightnessEnabled;
end;

function TfrmMain.getPaused: Boolean;
begin
  result := FPaused;
end;

procedure TfrmMain.SetHintAlready;
begin
  FHintAlready := True;
  Ini := TIniFile.Create( ChangeFileExt( Application.ExeName, '.INI' ) );
  try
    Ini.WriteBool('Form', 'HintAlready', FHintAlready);
  finally
    Ini.Free;
  end;
end;

procedure TfrmMain.UpdateLabels;
var
  s: String;
begin
  s := Format('Brightness Target %d%% offset[%d%%]', [FOpacity, FMinOffset]);
  mnuEnabled.Caption := s;
  gbOpacity.Caption := s;
end;

procedure TfrmMain.SetOffset(const Val: Integer);
begin
  FMinOffset := Val;
  UpdateLabels;
  if tbOffset.Position <> FMinOffset then
    tbOffset.Position := FMinOffset;
  FCaptureList.Update(FBrightnessEnabled, FOpacity, FMinOffset);
end;

procedure TfrmMain.SetOpacity(const Val: Integer);
begin
  FOpacity := Val;
  UpdateLabels;
  if tbOpacity.Position <> FOpacity then
    tbOpacity.Position := FOpacity;
  FCaptureList.Update(FBrightnessEnabled, FOpacity, FMinOffset);
end;

procedure TfrmMain.setPaused(const Value: Boolean);
var
  Changes: Boolean;
begin
  Changes := FPaused <> Value;
  FPaused := Value;
  mnuPause.Checked := FPaused;
  chkPause.Checked := FPaused;
  if Changes then
  begin
    FCaptureList.Trigger(FBrightnessEnabled, FOpacity, FMinOffset, FPaused);
  end;
  chkPause.Enabled := FBrightnessEnabled;
  mnuPause.Visible := FBrightnessEnabled;
end;

procedure TfrmMain.ShowMainAtCenter(ShowIt: Boolean);
var
  m: TMonitor;
  r: TRect;
begin
  m := screen.PrimaryMonitor;
  if Assigned(m) then
  begin
    r := m.WorkareaRect;
    frmMain.Top := r.Top + (r.Height - frmMain.Height) div 2;
    frmMain.Left := r.Left + (r.Width - frmMain.Width) div 2;
  end;
  if ShowIt then
  begin
    mnuShowClick(nil);
  end;
end;

procedure TfrmMain.tbOffsetChange(Sender: TObject);
begin
  SetOffset(tbOffset.Position);
end;

procedure TfrmMain.tbOpacityChange(Sender: TObject);
begin
  SetOpacity(tbOpacity.Position);
end;

procedure TfrmMain.tbOpacityKeyPress(Sender: TObject; var Key: Char);
begin
  if (Ord(Key) = VK_SPACE) or (Ord(Key) = VK_RETURN) then
  begin
    chkEnabled.Checked := not chkEnabled.Checked;
  end;
end;

procedure TfrmMain.chkEnabledClick(Sender: TObject);
begin
  BrightnessEnabled := chkEnabled.Checked;
end;

procedure TfrmMain.chkPauseClick(Sender: TObject);
begin
  Paused := chkPause.Checked;
end;

procedure TfrmMain.btnShowFormsClick(Sender: TObject);
var
  form: TForm;
  img: TImage;
  I: Integer;
  desktopCap: TDesktopDuplicationWrapper;
  s1, s2: String;
begin
  if not FIsNeedRecapture then
  begin
    for I := 0 to FCaptureList.Count -1 do
    begin
      desktopCap := FCaptureList.Items[I];
      form := TForm.Create(Application);
      s1 := desktopCap.Adaptor_Desc.Description;
      s2 := desktopCap.Output_Desc.DeviceName;
      form.Caption := '"' + s1 + '" -  "' + s2 + '"';
      form.show;
      img := TImage.Create(form);
      img.Align := alClient;
      img.Visible := True;
      img.Parent := form;
      Img.Picture.Graphic := desktopCap.Bitmap;
    end;
  end;
end;

procedure TfrmMain.CheckAndFixMainPositionIfOutOfScope;
var
  m: TMonitor;
  r: TRect;
  i: Integer;
  OutOfScope: Boolean;
begin
  try
    // make sure not in sleep mode first
    if isSystemAlive() then
    begin
      OutOfScope := True;
      // check if found in any screen
      for i := 0 to Screen.MonitorCount -1 do
      begin
         m := screen.Monitors[i];
         r := m.BoundsRect;
         if frmMain.ClientRect.IntersectsWith(r) then
         begin
           OutOfScope := False;
           Break;
         end;
      end;
      // set to default position
      if OutOfScope then
      begin
        ShowMainAtCenter();
      end;
    end;
  except
    // error? give it back to main screen
    ShowMainAtCenter();
  end;
end;

procedure TfrmMain.CheckDisplayChanged;
begin
  if FDisplayChanging then
    Exit;
  FDisplayChanging := True;
  try
    FIsNeedRecapture := True;
    FCaptureList.KillThreads;
    recreateCaptures;
  finally
    FDisplayChanging := False;
  end;
end;

procedure TfrmMain.mnuAutoRunClick(Sender: TObject);
begin
  SetAutoStart(ParamStr(0), 'Cuyo Brightness', mnuAutoRun.Checked);
end;

procedure TfrmMain.mnuEnabledClick(Sender: TObject);
begin
  BrightnessEnabled := not BrightNessEnabled;
end;

procedure TfrmMain.mnuExitClick(Sender: TObject);
begin
  FIsExit := True;
  Close;
end;

procedure TfrmMain.mnuPauseClick(Sender: TObject);
begin
  Paused := not Paused;
end;

procedure TfrmMain.mnuShowClick(Sender: TObject);
begin
  { Hide the tray icon and show the window,
  setting its state property to wsNormal. }
//  TrayIcon1.Visible := False;
  CheckAndFixMainPositionIfOutOfScope;
  Show();
  WindowState := wsNormal;
  Application.BringToFront();
end;

function TfrmMain.OnCheckIfNeedRecapture: Boolean;
begin
  Result := FIsNeedRecapture;
end;

procedure TfrmMain.setBEnabled(const Value: Boolean);
var
  Changes: Boolean;
begin
  Changes := FBrightnessEnabled <> Value;
  FBrightnessEnabled := Value;
  mnuEnabled.Checked := FBrightnessEnabled;
  chkEnabled.Checked := FBrightnessEnabled;
  if Changes then
  begin
    if FBrightnessEnabled then
    begin
      chkPause.Checked := False;
    end;
    FCaptureList.Trigger(FBrightnessEnabled, FOpacity, FMinOffset, FPaused);
  end;
  chkPause.Enabled := FBrightnessEnabled;
  mnuPause.Visible := FBrightnessEnabled;
end;

procedure TfrmMain.TrayIcon1DblClick(Sender: TObject);
begin
  mnuShowClick(nil);
end;

procedure TfrmMain.WMDisplayChange(var Message: TWMDisplayChange);
begin
  //  ShowMessageFmt('The screen resolution has changed to %d×%d×%d.',
  //    [Message.Width, Message.Height, Message.BitsPerPixel]);
  CheckDisplayChanged;
end;

function TfrmMain.isSystemAlive: Boolean;
var
  pt: TPoint;
begin
  { use this to detect if is sleeping mode }
  Result := GetCursorPos(pt);
end;

procedure TfrmMain.recreateCaptures;
begin
  { clear the old captures if got }
  FCaptureList.Clear;
  { lets detect the Screens' list }
  recreateScreenList;
  { lets put detected Adaptors' Screens' to list }
  FCaptureList.CreateCaptures(OnCheckIfNeedRecapture, FScreenList);
  FIsNeedRecapture := False;
  FCaptureList.Trigger(FBrightnessEnabled, FOpacity, FMinOffset, FPaused, TRUE);
  if FPaused then
  begin
    TThread.ForceQueue(nil,
      procedure
      begin
        Paused := False;
      end);
    TThread.ForceQueue(nil,
      procedure
      begin
        Paused := True;
      end);
  end;
end;

procedure TfrmMain.recreateScreenList;
var
//  DeviceMode: TDeviceMode;
  DisplayDevice: TDisplayDevice;
  Index: Integer;
  ScreenID: String;
  ScreenDC: HDC;
begin
  { clear the old screens }
  FScreenList.Clear;
  Index := 0;
  // get the name of a device by the given index
  DisplayDevice.cb := SizeOf(TDisplayDevice);
  while EnumDisplayDevices(nil, Index, DisplayDevice, 0) do
  begin
    ScreenID := StrPas(DisplayDevice.DeviceString) + StrPas(DisplayDevice.DeviceName);
    //VMware SVGA 3D\\.\DISPLAY1
    ScreenDC := CreateDC(nil, PChar(@DisplayDevice.DeviceName[0]), nil, nil);
    { add to list }
    FScreenList.Add(screenID, TScreenInfo.Create(ScreenID, ScreenDC));
    { next screen }
    inc(Index);
  end;
end;

end.
