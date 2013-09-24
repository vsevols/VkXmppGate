object frmMemoEdit: TfrmMemoEdit
  Left = 0
  Top = 0
  Caption = 'frmMemoEdit'
  ClientHeight = 202
  ClientWidth = 447
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Memo: TMemo
    Left = 16
    Top = 8
    Width = 385
    Height = 161
    Lines.Strings = (
      'Memo')
    TabOrder = 0
  end
  object Button1: TButton
    Left = 104
    Top = 175
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 1
  end
  object Button2: TButton
    Left = 185
    Top = 175
    Width = 75
    Height = 25
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
end
