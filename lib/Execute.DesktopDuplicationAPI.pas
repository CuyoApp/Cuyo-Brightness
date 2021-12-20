unit Execute.DesktopDuplicationAPI;
{
  Based on
  https://github.com/tothpaul/Delphi/tree/master/DesktopDuplicationAPI

  Desktop Duplication (c)2017 Execute SARL
  http://www.execute.fr
}
interface

uses
  Winapi.Windows, System.Classes, System.SysUtils,
  DX12.D3D11,
  DX12.D3DCommon,
  DX12.DXGI,
  DX12.DXGI1_2,
  Vcl.Graphics,
  Vcl.StdCtrls,
  System.SyncObjs,
  Common;

type
  TDesktopDuplicationWrapper = class;
  TNeedRecaptureCallback = function (Capture: TDesktopDuplicationWrapper): boolean of object;
  TOnCheckIfNeedRecapture = function (): boolean of object;

  { thread - do average calculation and apply brightness }
  TCaptureThread = class(TThread)
  private
    FPause: Boolean;
    FCapture: TDesktopDuplicationWrapper;
    FNeedRecaptureCallback: TNeedRecaptureCallback;
    FWaitSignal: TSimpleEvent;
    FNeedRecapture: Boolean;
    procedure CheckNeedRecapture;
    function NeedRecreate: Boolean;
  public
    constructor Create(Capture: TDesktopDuplicationWrapper; CallBack: TNeedRecaptureCallback); overload;
    destructor Destroy; override;
    procedure Execute;override;
    procedure Start;
    procedure Pause;
  end;

{$POINTERMATH ON} // Pointer[x]
  { Desktop Duplication API - by display }
  TDesktopDuplicationWrapper = class
  private
    FError: HRESULT;
  // D3D11
    GA: IDXGIAdapter1;
    GO: IDXGIOutput;
    O1: IDXGIOutput1;
    FDevice: ID3D11Device;
    FContext: ID3D11DeviceContext;
    FFeatureLevel: TD3D_FEATURE_LEVEL;
  // DGI
    FDuplicate: IDXGIOutputDuplication;
    FTexture: ID3D11Texture2D;
  // update information
    FMetaData: array of Byte;
    FMoveRects: PDXGI_OUTDUPL_MOVE_RECT; // array of
    FMoveCount: Integer;
    FDirtyRects: PRECT; // array of
    FDirtyCount: Integer;
  // description
    FAdaptor_Desc: TDXGI_ADAPTER_DESC;
    FOutput_Desc: TDXGI_OUTPUT_DESC;
  // DC to apply brightness
    FScreenDC: HDC;

    { brightness target }
    function OpacityGet: Integer;
    procedure OpacitySet(const Value: Integer);
    { screen average brightness calculation's offset }
    function MinOffsetGet: Integer;
    procedure MinOffsetSet(const Value: Integer);
  protected
    FOpacity: Integer;
    FMinOffset: Integer;
    FAverageBrightness: Integer;
    FOnCheckIfNeedRecapture: TOnCheckIfNeedRecapture;
    FCapture: TCaptureThread;
    FBitmap: TBitmap;
    FisError: Boolean;

    function CheckIfRecaptureNeeded(Capture: TDesktopDuplicationWrapper): Boolean;
    procedure Process;
    procedure ResetBrightness;
  public
    constructor Create(GA: IDXGIAdapter1; GO: IDXGIOutput; ScreenDC: HDC; OnCheckIfNeedRecapture: TOnCheckIfNeedRecapture);
    destructor Destroy; override;
    function GetFrame: Boolean;
    procedure DrawFrame(var Bitmap: TBitmap);
    property Error: HRESULT read FError;
    property MoveCount: Integer read FMoveCount;
    property MoveRects: PDXGI_OUTDUPL_MOVE_RECT read FMoveRects;
    property DirtyCount: Integer read FDirtyCount;
    property DirtyRects: PRect read FDirtyRects;
    property Adaptor_Desc: TDXGI_ADAPTER_DESC read FAdaptor_Desc;
    property Output_Desc: TDXGI_OUTPUT_DESC read FOutput_Desc;
    property Thread: TCaptureThread read FCapture;
    property AverageBrightness: Integer read FAverageBrightness;
    property Bitmap: TBitmap read FBitmap;
    property Opacity: Integer read OpacityGet write OpacitySet;
    property MinOffset: Integer read MinOffsetGet write MinOffsetSet;
  end;

implementation

{ TDesktopDuplicationWrapper }

function TDesktopDuplicationWrapper.CheckIfRecaptureNeeded(
  Capture: TDesktopDuplicationWrapper): Boolean;
begin
  Result := False;
  if Self = Capture then
  begin
    if Assigned(FOnCheckIfNeedRecapture) then
      Result := FOnCheckIfNeedRecapture;
  end;
end;

constructor TDesktopDuplicationWrapper.Create(GA: IDXGIAdapter1; GO: IDXGIOutput; ScreenDC: HDC; OnCheckIfNeedRecapture: TOnCheckIfNeedRecapture);
begin
  Self.GA := GA;
  Self.GO := GO;
  Self.FScreenDC := ScreenDC;

  FBitmap := TBitmap.Create;
  FAverageBrightness := 50;
  FMinOffset := 0;

  FOnCheckIfNeedRecapture := OnCheckIfNeedRecapture;

  FError := D3D11CreateDevice(
    GA, { by Adaptor } // note: nil for Default adapter
    D3D_DRIVER_TYPE_UNKNOWN, // note: D3D_DRIVER_TYPE_HARDWARE, // A hardware driver, which implements Direct3D features in hardware.
    0,
    0,
    nil, 0, // default feature
    D3D11_SDK_VERSION,
    FDevice,
    FFeatureLevel,
    FContext
  );
  if Failed(FError) then
    Exit;

  { Adaptor desc }
  GA.GetDesc(FAdaptor_Desc);

  { Output desc }
  FError := GO.GetDesc(FOutput_Desc);
  if Failed(FError) then
    Exit;

  { retrieve the read output }
  FError := GO.QueryInterface(IID_IDXGIOutput1, O1);
  if Failed(FError) then
    Exit;

  { duplicate the output } { by display }
  FError := O1.DuplicateOutput(FDevice, FDuplicate);
  if Failed(FError) then
    Exit;

  FCapture := TCaptureThread.Create(Self, CheckIfRecaptureNeeded);
end;

destructor TDesktopDuplicationWrapper.Destroy;
begin
  FreeAndNil(FBitmap); //FBitmap.Free;
  FreeAndNil(FCapture); //FCapture.Free;
  inherited;
end;

procedure TDesktopDuplicationWrapper.DrawFrame(var Bitmap: TBitmap);
var
  Desc: TD3D11_TEXTURE2D_DESC;
  Temp: ID3D11Texture2D;
  Resource: TD3D11_MAPPED_SUBRESOURCE;
  i: Integer;
  p: PByte;
begin
  FTexture.GetDesc(Desc);

  Bitmap.PixelFormat := pf32Bit;
  Bitmap.SetSize(Desc.Width, Desc.Height);

  Desc.BindFlags := 0;
  Desc.CPUAccessFlags := Ord(D3D11_CPU_ACCESS_READ) or Ord(D3D11_CPU_ACCESS_WRITE);
  Desc.Usage := D3D11_USAGE_STAGING;
  Desc.MiscFlags := 0;

  //  READ/WRITE texture
  FError := FDevice.CreateTexture2D(@Desc, nil, Temp);
  if Failed(FError) then
    Exit;

  // copy original to the RW texture
  FContext.CopyResource(Temp, FTexture);

  // get texture bits
  FContext.Map(Temp, 0, D3D11_MAP_READ_WRITE, 0, Resource);
  p := Resource.pData;

  // copy pixels - we assume a 32bits bitmap !
  for i := 0 to Desc.Height - 1 do
  begin
    Move(p^, Bitmap.ScanLine[i]^, 4 * Desc.Width);
    Inc(p, 4 * Desc.Width);
  end;

  FTexture := nil;
  FDuplicate.ReleaseFrame;
end;

function TDesktopDuplicationWrapper.GetFrame: Boolean;
var
  FrameInfo: TDXGI_OUTDUPL_FRAME_INFO;
  Resource: IDXGIResource;
  BufLen : Integer;
  BufSize: Uint;
begin
  Result := False;

  if FTexture <> nil then
  begin
    FTexture := nil;
    FDuplicate.ReleaseFrame;
  end;

  FError := FDuplicate.AcquireNextFrame(0, FrameInfo, Resource);
  if FError = DXGI_ERROR_ACCESS_LOST then
  begin
    { Direct3D Desktop Duplication: How to Recover From Changing Screen Resolution?
      https://stackoverflow.com/questions/31211282/direct3d-desktop-duplication-how-to-recover-from-changing-screen-resolution }
    O1.DuplicateOutput(FDevice, FDuplicate); { retry }
  end;
  if Failed(FError) then
    Exit;

  if FrameInfo.TotalMetadataBufferSize > 0 then
  begin
    FError := Resource.QueryInterface(IID_ID3D11Texture2D, FTexture);
    if failed(FError) then
      Exit;

    Resource := nil;

    BufLen := FrameInfo.TotalMetadataBufferSize;
    if Length(FMetaData) < BufLen then
      SetLength(FMetaData, BufLen);

    FMoveRects := Pointer(FMetaData);

    FError := FDuplicate.GetFrameMoveRects(BufLen, FMoveRects, BufSize);
    if Failed(FError) then
      Exit;
    FMoveCount := BufSize div sizeof(TDXGI_OUTDUPL_MOVE_RECT);

    FDirtyRects := @FMetaData[BufSize];
    Dec(BufLen, BufSize);

    FError := FDuplicate.GetFrameDirtyRects(BufLen, FDirtyRects, BufSize);
    if Failed(FError) then
      Exit;
    FDirtyCount := BufSize div sizeof(TRECT);

    Result := True;
  end else begin
    FDuplicate.ReleaseFrame;
  end;
end;

function TDesktopDuplicationWrapper.MinOffsetGet: Integer;
begin
  Result := FMinOffset;
end;

procedure TDesktopDuplicationWrapper.MinOffsetSet(const Value: Integer);
var
  I: Integer;
begin
  if Value < 0 then
    I := 0
  else if Value > 100 then
    I := 100
  else
    I := Value;
  FMinOffset := I;
end;

function TDesktopDuplicationWrapper.OpacityGet: Integer;
begin
  Result := FOpacity;
end;

procedure TDesktopDuplicationWrapper.OpacitySet(const Value: Integer);
var
  I: Integer;
begin
  if Value < 0 then
    I := 0
  else if Value > 100 then
    I := 100
  else
    I := Value;
  FOpacity := I;
end;

{ based on https://github.com/Fushko/gammy }
function calcBrightness(const p: TRGBQuad): Double;
begin
	Result := (p.rgbRed * 0.2126 + p.rgbBlue * 0.7152 + p.rgbBlue * 0.0722) *100/255; { return 0-100 }
end;

function calcAvgBrightness(bmp: TBitmap): Integer;
type
   TRGBQuadArray = ARRAY[Word] of TRGBQuad;
   PRGBQuadArray = ^TRGBQuadArray;
var
  X, Y: Integer;
  pY: PRGBQuadArray;
  p: TRGBQuad;
  brightness: Double;
  totalBrightness: Double;
begin
  totalBrightness := 0.0;

  for Y := 0 to bmp.Height-1 do
  begin
    pY := bmp.Scanline[y];
    for X := 0 to bmp.Width-1 do
    begin
      p := py^[X];
      brightness := calcBrightness(p);
      totalBrightness := totalBrightness + brightness;
    end;
  end;
  Result := Trunc(totalBrightness / (bmp.Width * bmp.Height));
end;

{ calculate the average - apply brightness target and offset }
procedure TDesktopDuplicationWrapper.Process;
var
  pt: TPoint;
  avg, offset: Integer;
begin
  { use this to detect if in sleeping mode }
  if not GetCursorPos(pt) then Exit;

  try
    if not FisError and Self.GetFrame then
    begin
      Self.DrawFrame(FBitmap);

      { FOpacity target 0-100% }
      FAverageBrightness := calcAvgBrightness(FBitmap);

      { average and offset thingy }
      avg := FAverageBrightness;
      { still a bit bright -- add offset }
      avg := avg + FMinOffset;
      if avg < 0 then
        avg := 0
      else if avg > 100 then
        avg := 100;
      { calculate offset to dim the screen } // Note: currently only do dimming
      { offset =  128 - ((current - target)*128/100) }
      offset := Trunc(128- ((avg - FOpacity)*128/100));
      if offset < 0 then
        offset := 0
      { if offset > 128 no need increase brightness }
      else if (offset > 128) then
        offset := 128;
      SetDisplayBrightness(FScreenDC, offset);
      // 128       = normal brightness
      // above 128 = brighter { <-- not doing this part}
      // below 128 = darker

    end else
    begin
      { no changes... or sometimes API error, skip! }
    end;
  except
    { crash! Stop futher processing... } //TODO: prompt? log?
    FisError := True;
  end;
end;

procedure TDesktopDuplicationWrapper.ResetBrightness;
begin
  SetDisplayBrightness(FScreenDC, 128); { normal brightness }
end;


{ TCaptureThread }

constructor TCaptureThread.Create(Capture: TDesktopDuplicationWrapper; CallBack: TNeedRecaptureCallback);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWaitSignal := TSimpleEvent.Create();
  FCapture := Capture;
  FNeedRecaptureCallback := CallBack;
end;

destructor TCaptureThread.Destroy;
begin
  FPause := True;
  Terminate;
  FWaitSignal.SetEvent;
  Self.WaitFor;
  FreeAndNil(FWaitSignal); //FWaitSignal.Free;
  inherited;
end;

procedure TCaptureThread.Execute;
begin
  while (not Terminated) do
  begin
    FWaitSignal.WaitFor(500);
    FWaitSignal.ResetEvent;
    if Terminated then
      Exit;
    if FPause then
      continue;
    Synchronize(CheckNeedRecapture);
    if Terminated then
      Exit;
    if FPause then
      continue;
    if FNeedRecapture then
      Exit; { end thread }
    FCapture.Process;
  end;
end;

procedure TCaptureThread.CheckNeedRecapture; { Synchronize }
begin
  FNeedRecapture := NeedRecreate;
end;

function TCaptureThread.NeedRecreate: Boolean;
begin
  Result := False;
  if Assigned(FNeedRecaptureCallback) then
    Result := FNeedRecaptureCallback(FCapture);
end;

procedure TCaptureThread.Pause;
begin
  FPause := True;
  FCapture.ResetBrightness;
end;

procedure TCaptureThread.Start;
begin
  if not Started then
    inherited Start;
  FPause := False;
end;

end.
