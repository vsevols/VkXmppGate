program XmppGateTest;

uses
  Forms,
  TestFramework,
  GUITestRunner,
  IWInit,
  IWGlobal,
  IWTestCase1 in 'IWTestCase1.pas';

{$R *.res}

begin
  GAppModeInit(Application);
  TGUITestRunner.runRegisteredTests;
end.
