object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 606
  ClientWidth = 213
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 120
    Width = 3
    Height = 13
  end
  object btnStart: TButton
    Left = 8
    Top = 153
    Width = 75
    Height = 25
    Caption = 'Start'
    TabOrder = 0
    OnClick = btnStartClick
  end
  object btnCancel: TButton
    Left = 128
    Top = 153
    Width = 75
    Height = 25
    Caption = 'Cancel'
    Enabled = False
    TabOrder = 1
    OnClick = btnCancelClick
  end
  object edtMaxNum: TEdit
    Left = 8
    Top = 16
    Width = 195
    Height = 21
    TabOrder = 2
    Text = '10000'
  end
  object ProgressBar1: TProgressBar
    Left = 8
    Top = 47
    Width = 195
    Height = 20
    TabOrder = 3
  end
  object edtPrime: TEdit
    Left = 8
    Top = 77
    Width = 195
    Height = 21
    TabOrder = 4
  end
  object btnStartAll: TButton
    Left = 8
    Top = 494
    Width = 75
    Height = 25
    Caption = 'Start All'
    TabOrder = 5
    OnClick = btnStartAllClick
  end
  object btnCancelAll: TButton
    Left = 128
    Top = 494
    Width = 75
    Height = 25
    Caption = 'Cancel All'
    TabOrder = 6
    OnClick = btnCancelAllClick
  end
  object ProgressBar2: TProgressBar
    Left = 8
    Top = 199
    Width = 195
    Height = 20
    TabOrder = 7
  end
  object ProgressBar3: TProgressBar
    Left = 8
    Top = 231
    Width = 195
    Height = 20
    TabOrder = 8
  end
  object ProgressBar4: TProgressBar
    Left = 8
    Top = 263
    Width = 195
    Height = 20
    TabOrder = 9
  end
  object ProgressBar5: TProgressBar
    Left = 8
    Top = 295
    Width = 195
    Height = 20
    TabOrder = 10
  end
  object ProgressBar6: TProgressBar
    Left = 8
    Top = 327
    Width = 195
    Height = 20
    TabOrder = 11
  end
  object ProgressBar7: TProgressBar
    Left = 8
    Top = 359
    Width = 195
    Height = 20
    TabOrder = 12
  end
  object ProgressBar8: TProgressBar
    Left = 8
    Top = 391
    Width = 195
    Height = 20
    TabOrder = 13
  end
  object ProgressBar9: TProgressBar
    Left = 8
    Top = 423
    Width = 195
    Height = 20
    TabOrder = 14
  end
  object edtThreadNum: TEdit
    Left = 8
    Top = 462
    Width = 195
    Height = 21
    TabOrder = 15
    Text = '8'
  end
  object Edit1: TEdit
    Left = 8
    Top = 117
    Width = 195
    Height = 21
    TabOrder = 16
    Text = 'Edit1'
  end
  object Edit2: TEdit
    Left = 8
    Top = 541
    Width = 195
    Height = 21
    TabOrder = 17
    Text = 'Edit1'
  end
  object Timer1: TTimer
    OnTimer = Timer1Timer
    Left = 88
    Top = 152
  end
end
