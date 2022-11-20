object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Cuyo Brightness'
  ClientHeight = 119
  ClientWidth = 261
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object gbOpacity: TGroupBox
    AlignWithMargins = True
    Left = 8
    Top = 8
    Width = 245
    Height = 103
    Margins.Left = 8
    Margins.Top = 8
    Margins.Right = 8
    Margins.Bottom = 8
    Align = alClient
    Caption = 'Brightness Target'
    TabOrder = 0
    DesignSize = (
      245
      103)
    object tbOpacity: TTrackBar
      Left = 0
      Top = 40
      Width = 242
      Height = 33
      Hint = 'Target'
      Anchors = [akLeft, akTop, akRight]
      Max = 100
      ParentShowHint = False
      ShowHint = True
      ShowSelRange = False
      TabOrder = 2
      OnChange = tbOpacityChange
      OnKeyPress = tbOpacityKeyPress
    end
    object chkEnabled: TCheckBox
      Left = 8
      Top = 20
      Width = 97
      Height = 17
      Caption = 'Enable'
      TabOrder = 0
      OnClick = chkEnabledClick
    end
    object tbOffset: TTrackBar
      Left = 0
      Top = 72
      Width = 242
      Height = 25
      Hint = 'Minimun Offset'
      Anchors = [akLeft, akTop, akRight]
      Max = 100
      ParentShowHint = False
      ShowHint = True
      ShowSelRange = False
      TabOrder = 3
      OnChange = tbOffsetChange
      OnKeyPress = tbOpacityKeyPress
    end
    object chkPause: TCheckBox
      Left = 81
      Top = 20
      Width = 65
      Height = 17
      Caption = 'Pause'
      TabOrder = 1
      OnClick = chkPauseClick
    end
  end
  object btnShowForms: TButton
    Left = 160
    Top = 24
    Width = 81
    Height = 21
    Caption = '&Show Forms'
    TabOrder = 1
    Visible = False
    OnClick = btnShowFormsClick
  end
  object ApplicationEvents1: TApplicationEvents
    OnMinimize = ApplicationEvents1Minimize
    Left = 24
    Top = 112
  end
  object TrayIcon1: TTrayIcon
    PopupMenu = PopupMenu1
    OnDblClick = TrayIcon1DblClick
    Left = 200
    Top = 112
  end
  object PopupMenu1: TPopupMenu
    Left = 120
    Top = 112
    object mnuShow: TMenuItem
      Caption = '&Show Settings.'
      Default = True
      OnClick = mnuShowClick
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object mnuEnabled: TMenuItem
      Caption = '&Brightness Target 50%'
      OnClick = mnuEnabledClick
    end
    object mnuPause: TMenuItem
      Caption = '&Pause'
      OnClick = mnuPauseClick
    end
    object mnuAutoRun: TMenuItem
      AutoCheck = True
      Caption = '&Run at startup'
      OnClick = mnuAutoRunClick
    end
    object N2: TMenuItem
      Caption = '-'
    end
    object mnuExit: TMenuItem
      Caption = '&Exit'
      OnClick = mnuExitClick
    end
  end
end
