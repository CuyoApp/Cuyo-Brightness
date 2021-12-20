program Cuyo;

uses
  Windows, Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  DX12.D3D11 in 'DXHeaders\DX12.D3D11.pas',
  DX12.D3DCommon in 'DXHeaders\DX12.D3DCommon.pas',
  DX12.DXGI in 'DXHeaders\DX12.DXGI.pas',
  DX12.DXGI1_2 in 'DXHeaders\DX12.DXGI1_2.pas',
  Execute.DesktopDuplicationAPI in 'lib\Execute.DesktopDuplicationAPI.pas',
  Execute.Managers in 'lib\Execute.Managers.pas',
  Common in 'lib\Common.pas';

{$R *.res}
{$DYNAMICBASE ON}  // Enable DEP, trying to pass virus total...

function CreateSingleInstance(const InstanceName: string): boolean;
var
  MutexHandle: THandle;
begin
  MutexHandle := CreateMutex(nil, false, PChar(InstanceName));
  // if MutexHandle created check if already exists
  if (MutexHandle <> 0) then
  begin
    if GetLastError = ERROR_ALREADY_EXISTS then
    begin
      Result := false;
      CloseHandle(MutexHandle);
    end
    else Result := true;
  end
  else Result := false;
end;

var
  MyInstanceName: string;

begin
  try
    {$IFDEF DEBUG}ReportMemoryLeaksOnShutdown:= true;{$ENDIF}
    MyInstanceName := 'Cuyo Brightness';
    Application.Initialize;
    // Initialize MyInstanceName here
    if CreateSingleInstance(MyInstanceName) then
    begin
      Application.MainFormOnTaskbar := True;
      Application.Title := 'Cuyo Brightness';
      Application.CreateForm(TfrmMain, frmMain);
      Application.Run;
    end;
  except
    // No code is required here, trying to pass virus total...
  end;
end.
