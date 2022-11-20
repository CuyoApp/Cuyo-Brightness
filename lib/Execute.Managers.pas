unit Execute.Managers;

interface

uses Winapi.Windows, System.SysUtils,
  DX12.D3D11,
  DX12.D3DCommon,
  DX12.DXGI,
  DX12.DXGI1_2
  , Generics.Collections
  , Execute.DesktopDuplicationAPI
  , Common;

type
 TScreenList = class;

 TExecuteList = class(TList<TDesktopDuplicationWrapper>)
 public
   constructor Create;
   destructor Destroy; override;

   function CreateCaptures(OnCheckIfNeedRecapture: TOnCheckIfNeedRecapture; ScreenList: TScreenList): Boolean;
   procedure Trigger(Enabled: Boolean; Opacity: Integer; MinOffset: Integer; Paused: Boolean; Recaptured: Boolean = False);
   procedure Update(Enabled: Boolean; Opacity: Integer; MinOffset: Integer);
   procedure Clear; reintroduce;
   procedure KillThreads;
 end;

 TScreenInfo = class
 public
   ID: String; { Key: by Adaptor by Screen }
   DC: HDC; { DC for API SetDisplayBrightness }

   constructor Create(ScreenID: String; ScreenDC: HDC);
   destructor Destroy; override;
 end;

 TScreenList = class(TObjectDictionary<String, TScreenInfo>)
 public
   constructor Create;
   destructor Destroy; override;
 end;

implementation


{ TExecuteList }

constructor TExecuteList.Create;
begin
  inherited Create;
end;

destructor TExecuteList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TExecuteList.Clear;
var
  Capture: TDesktopDuplicationWrapper;
  I: Integer;
begin
  for I := 0 to Count -1 do
  begin
    Capture := Items[I];
    Capture.Free;
  end;
  inherited Clear;
end;

procedure TExecuteList.KillThreads;
begin
  Clear;
end;

procedure TExecuteList.Trigger(Enabled: Boolean; Opacity: Integer; MinOffset: Integer; Paused: Boolean; Recaptured: Boolean = False);
var
  Capture: TDesktopDuplicationWrapper;
  I: Integer;
begin
  for I := 0 to Count -1 do
  begin
    Capture := Items[I];
    if Enabled then
    begin
      Capture.Opacity := Opacity;
      Capture.MinOffset := MinOffset;
      Capture.Paused := Paused;
      Capture.Recaptured := Recaptured;
      Capture.Thread.Start;
    end else
    begin
      Capture.Thread.Pause;
    end;
  end;
end;

procedure TExecuteList.Update(Enabled: Boolean; Opacity: Integer; MinOffset: Integer);
var
  Capture: TDesktopDuplicationWrapper;
  I: Integer;
begin
  for I := 0 to Count -1 do
  begin
    Capture := Items[I];
    if Enabled then
    begin
      Capture.Opacity := Opacity;
      Capture.MinOffset := MinOffset;
      Capture.Thread.Start;
    end else
    begin
      Capture.Thread.Pause;
    end;
  end;
end;

function TExecuteList.CreateCaptures(OnCheckIfNeedRecapture: TOnCheckIfNeedRecapture; ScreenList: TScreenList): Boolean;
var
  GA: IDXGIAdapter1;
  GO: IDXGIOutput;

  GF: IDXGIFactory1;
  GA_desc: TDXGI_ADAPTER_DESC;
  GO_desc: TDXGI_OUTPUT_DESC;
  ScreenID: String;
  ScreenInfo: TScreenInfo;

  I, J: Integer;

  FError: HRESULT;
begin
  Result := False;

  { create factory to get each adaptors out }
  FError := CreateDXGIFactory1(IID_IDXGIFactory1, GF);
  if Failed(FError) then
    Exit;
  { prepare to loop }
  I := 0; FError := S_OK;
  { loop all the adaptor }
  while not Failed(FError) do
  begin
    { enum adaptors }
    FError := GF.EnumAdapters1(I, GA);
    inc(I); { next adaptor }
    { check if ok }
    if not Failed(FError) then
    begin
      { get Adaptor's desc }
      GA.GetDesc(GA_desc);
      { prepare to loop for screens }
      J := 0;
      repeat
        FError := GA.EnumOutputs(J, GO);
        inc(J); { next screen }
        if not Failed(FError) then
        begin
          GO.GetDesc(GO_desc);
          { screen id }
          ScreenID := StrPas(GA_desc.Description) + StrPas(GO_desc.DeviceName);
          { try store the valid screen to list }
          if ScreenList.TryGetValue(ScreenID, ScreenInfo) then
          begin
            { add the wrapper }
            Add(TDesktopDuplicationWrapper.Create(GA, GO, ScreenInfo.DC, OnCheckIfNeedRecapture));
          end;
          // eg.
          //VMware SVGA 3D
          // -\\.\DISPLAY1

          //NVIDIA GeForce RTX 2070
          // -\\.\DISPLAY1
          // -\\.\DISPLAY2
        end;
      until (Failed(FError));
    end;
  end;
end;


{ TScreenList }

constructor TScreenList.Create;
begin
  inherited Create([doOwnsValues]);
end;

destructor TScreenList.Destroy;
begin

  inherited;
end;


{ TScreenInfo }

constructor TScreenInfo.Create(ScreenID: String; ScreenDC: HDC);
begin
  ID := ScreenID;
  DC := ScreenDC;
end;

destructor TScreenInfo.Destroy;
begin
  { no need restore }
  //SetDisplayBrightness(DC, 128); { restore brightness }
  ReleaseDC(0, DC);
  inherited;
end;

end.
