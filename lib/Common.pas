unit Common;

interface

uses
  Winapi.Windows, System.Classes, System.SysUtils;

function SetDisplayBrightness(ScreenDC: HDC; Brightness: Byte): Boolean;

implementation

function SetDisplayBrightness(ScreenDC: HDC; Brightness: Byte): Boolean;
//https://github.com/tothpaul/Delphi/tree/master/DesktopDuplicationAPI
//    SetDisplayBrightness
//
//    Changes the brightness of the entire screen.
//    This function may not work properly in some video cards.
//
//    The Brightness parameter has the following meaning:
//
//      128       = normal brightness
//      above 128 = brighter
//      below 128 = darker
var
  GammaDC: HDC;
  GammaArray: array[0..2, 0..255] of Word;
  I, Value: Integer;
begin
  Result := False;
  GammaDC := ScreenDC; //GetDC(0);

  if GammaDC <> 0 then
  begin
    for I := 0 to 255 do
    begin
      Value := I * (Brightness + 128);
      if Value > 65535 then
        Value := 65535;
      GammaArray[0, I] := Value; // R value of I is mapped to brightness of Value
      GammaArray[1, I] := Value; // G value of I is mapped to brightness of Value
      GammaArray[2, I] := Value; // B value of I is mapped to brightness of Value
    end;

    // Note: BOOL will be converted to Boolean here.
    Result := SetDeviceGammaRamp(GammaDC, GammaArray);

//    ReleaseDC(0, GammaDC);
  end;
end;

end.
