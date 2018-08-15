object Form1: TForm1
  Left = 192
  Top = 124
  Caption = 'Form1'
  ClientHeight = 209
  ClientWidth = 398
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object cbShowTrayBalloons: TCheckBox
    Left = 104
    Top = 40
    Width = 185
    Height = 17
    Caption = #1055#1086#1082#1072#1079#1099#1074#1072#1090#1100' '#1091#1074#1077#1076#1086#1084#1083#1077#1085#1080#1103' '#1074' '#1090#1088#1077#1077
    TabOrder = 0
  end
  object btnRestartServer: TButton
    Left = 80
    Top = 96
    Width = 209
    Height = 25
    Caption = #1055#1077#1088#1077#1079#1072#1087#1091#1089#1090#1080#1090#1100' '#1089#1077#1088#1074#1077#1088
    TabOrder = 1
    OnClick = btnRestartServerClick
  end
  object Timer: TTimer
    Interval = 30000
    OnTimer = TimerTimer
    Left = 208
    Top = 144
  end
end
