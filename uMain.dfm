object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'frmMain'
  ClientHeight = 628
  ClientWidth = 213
  Color = clBtnFace
  Font.Charset = GB2312_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Fixedsys'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 16
  object Label1: TLabel
    Left = 9
    Top = 154
    Width = 104
    Height = 16
    Caption = 'Execute State'
  end
  object btnStart: TButton
    Left = 9
    Top = 185
    Width = 75
    Height = 25
    Caption = 'Start'
    TabOrder = 0
    OnClick = btnStartClick
  end
  object btnCancel: TButton
    Left = 129
    Top = 185
    Width = 75
    Height = 25
    Caption = 'Cancel'
    Enabled = False
    TabOrder = 1
    OnClick = btnCancelClick
  end
  object edtMaxNum: TEdit
    Left = 9
    Top = 16
    Width = 195
    Height = 24
    TabOrder = 2
    Text = '10000'
  end
  object ProgressBar1: TProgressBar
    Left = 9
    Top = 47
    Width = 195
    Height = 20
    TabOrder = 3
  end
  object ProgressBar2: TProgressBar
    Left = 8
    Top = 263
    Width = 195
    Height = 20
    TabOrder = 15
  end
  object ProgressBar3: TProgressBar
    Left = 8
    Top = 295
    Width = 195
    Height = 20
    TabOrder = 8
  end
  object ProgressBar4: TProgressBar
    Left = 8
    Top = 327
    Width = 195
    Height = 20
    TabOrder = 9
  end
  object ProgressBar5: TProgressBar
    Left = 8
    Top = 359
    Width = 195
    Height = 20
    TabOrder = 10
  end
  object ProgressBar6: TProgressBar
    Left = 8
    Top = 391
    Width = 195
    Height = 20
    TabOrder = 11
  end
  object ProgressBar7: TProgressBar
    Left = 8
    Top = 423
    Width = 195
    Height = 20
    TabOrder = 12
  end
  object ProgressBar8: TProgressBar
    Left = 8
    Top = 455
    Width = 195
    Height = 20
    TabOrder = 13
  end
  object ProgressBar9: TProgressBar
    Left = 8
    Top = 487
    Width = 195
    Height = 20
    TabOrder = 14
  end
  object edtPrime: TEdit
    Left = 9
    Top = 77
    Width = 195
    Height = 24
    TabOrder = 4
  end
  object Edit1: TEdit
    Left = 9
    Top = 117
    Width = 195
    Height = 24
    TabOrder = 5
    Text = 'Edit1'
  end
  object btnSuspend: TButton
    Left = 9
    Top = 221
    Width = 75
    Height = 25
    Caption = 'Suspend'
    TabOrder = 6
    OnClick = btnSuspendClick
  end
  object btnResume: TButton
    Left = 129
    Top = 221
    Width = 75
    Height = 25
    Caption = 'Resume'
    TabOrder = 7
    OnClick = btnResumeClick
  end
  object btnStartAll: TButton
    Left = 8
    Top = 529
    Width = 93
    Height = 25
    Caption = 'Start All'
    TabOrder = 16
    OnClick = btnStartAllClick
  end
  object btnCancelAll: TButton
    Left = 107
    Top = 529
    Width = 98
    Height = 25
    Caption = 'Cancel All'
    Enabled = False
    TabOrder = 17
    OnClick = btnCancelAllClick
  end
  object btnSuspendAll: TButton
    Left = 8
    Top = 573
    Width = 93
    Height = 25
    Caption = 'Suspend All'
    TabOrder = 18
    OnClick = btnSuspendAllClick
  end
  object btnResumeAll: TButton
    Left = 107
    Top = 573
    Width = 98
    Height = 25
    Caption = 'Resume All'
    TabOrder = 19
    OnClick = btnResumeAllClick
  end
  object cbDlg: TCheckBox
    Left = 129
    Top = 155
    Width = 97
    Height = 17
    Caption = 'Dlg'
    Checked = True
    State = cbChecked
    TabOrder = 20
  end
  object Timer1: TTimer
    Interval = 300
    OnTimer = Timer1Timer
    Left = 85
    Top = 80
  end
end
