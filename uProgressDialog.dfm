object ProgressDialog: TProgressDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Progress Dialog'
  ClientHeight = 142
  ClientWidth = 398
  Color = clBtnFace
  Font.Charset = GB2312_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Fixedsys'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 16
  object Label0: TLabel
    Left = 20
    Top = 16
    Width = 48
    Height = 16
    Caption = 'Label0'
  end
  object Label1: TLabel
    Left = 20
    Top = 38
    Width = 48
    Height = 16
    Caption = 'Label1'
  end
  object ProgressBar1: TProgressBar
    Left = 20
    Top = 68
    Width = 353
    Height = 21
    TabOrder = 0
  end
  object btnCancel: TButton
    Left = 148
    Top = 103
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    TabOrder = 1
    OnClick = btnCancelClick
  end
end
