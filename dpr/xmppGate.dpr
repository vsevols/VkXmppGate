program xmppGate;


uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  JabberServerSession in 'JabberServerSession.pas',
  ufrmMemoEdit in 'ufrmMemoEdit.pas' {frmMemoEdit},
  GateCore in 'GateCore.pas',
  JabberServer in 'JabberServer.pas',
  VKClientSession in 'VKClientSession.pas',
  VKtoXMPPSession in 'VKtoXMPPSession.pas',
  GateGlobals in 'GateGlobals.pas',
  GateFakes in 'GateFakes.pas',
  GateXml in 'GateXml.pas',
  VkLongPollClient in 'VkLongPollClient.pas',
  vkApi in 'vkApi.pas',
  GateVkCaptcha in 'GateVkCaptcha.pas',
  FileVersion in 'FileVersion.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TfrmMemoEdit, frmMemoEdit);
  Application.Run;
end.
