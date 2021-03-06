unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, IdContext, IdBaseComponent, IdComponent, IdCustomTCPServer,
  IdTCPServer, Vcl.StdCtrls, IdGlobal, IdExplicitTLSClientServerBase,
  VKClientSession, GateCore, TextTrayIcon, Vcl.ExtCtrls;

type
  TForm1 = class(TForm)
    cbShowTrayBalloons: TCheckBox;
    Timer: TTimer;
    btnRestartServer: TButton;
    procedure AppIdle(Sender: TObject; var Done: Boolean);
    procedure btnRestartServerClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure TrayClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure serv_Disconnect(AContext: TIdContext);
    procedure Test2;
    procedure TimerTimer(Sender: TObject);
  private
    bConnected: Boolean;
    bPsiOrder: Boolean;
    core: TGateCore;
    dtLastAppIdle: TDateTime;
    num: Integer;
    serv: TIDExplicitTLSServer;
    sSend: string;
    TrayIcon: TTextTrayIcon;
    procedure AppException(Sender: TObject; E: Exception);
    procedure DecClients;
    procedure IncClients;
    procedure InitTrayIcon;
    procedure TestSendMessage(vk: TVkClientSession);
    procedure UpdateGui(bInform: boolean);
    { Private declarations }
  public
    function TempEmojiHexToSmb(sHex: string): RawByteString;
    function TempEmojiImgToDec(sImg: string): string;
    procedure TempEmojiPack;
    procedure Test1;
    function UTF8BytesToString(bytes: TIdBytes): string;
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  IdTCPClient, System.DateUtils, IdSSL, System.StrUtils, JabberServerSession,
  GateGlobals, uvsDebug, CoolTrayIcon, janXMLparser2, GateXml,
  IdHTTP;

{$R *.dfm}

procedure TForm1.FormDestroy(Sender: TObject);
begin
  core.Free;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  bConnected:=false;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  args: array of string;
begin
  SetLength(args, 0);
  //VkCall('users.get', args, false);
end;

procedure TForm1.DecClients;
begin
  cs.Enter;

  //Dec(ClientCount);
  ClientCount:=core.Jab.tcp.Contexts.Count;
  UpdateGui(true);

  cs.Leave;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  bTerminate:=true;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  isDbg:=true;
//  isDbg:=false;
  //bFakes:=true;

  //bLongPollLog:=true;
  //bVkApiLog:=true;
  bXmppLog:=true;

 // if isDbg then
   // TempEmojiPack;

  if not isDbg then
  begin
    bLongPollLog:=false;
    bXmppLog:=false;
    bFakes:=false;
    bVkApiLog:=false;
  end;


  //xmlForm:=Self;
  Application.OnException:=AppException;
  Application.OnIdle:=AppIdle;

  //if isDbg then
    //Test2;

  InitTrayIcon;
  Application.ShowMainForm:=false;


    try
      core:=TGateCore.Create(nil);
      core.IncClients:=IncClients;
      core.DecClients:=DecClients;
      core.Init;
    finally
      UpdateGui(false);
    end;
end;

procedure TForm1.AppException(Sender: TObject; E: Exception);
begin
   //Socket Error # 10060 Connection timed out
   //if Pos('10060', e.Message)<>0 then

   GateLog(Format('Sender: %s ; %s', [ToHex(Cardinal(Sender)), e.Message]));
end;


procedure TForm1.AppIdle(Sender: TObject; var Done: Boolean);
begin
  Done:=true;

  exit;

  if SecondsBetween(dtLastAppIdle, Now)<30 then
    exit;
  dtLastAppIdle:=Now;

end;

procedure TForm1.btnRestartServerClick(Sender: TObject);
begin
  RestartServer(nil, nil, core.ServName, 'Restarting from GUI');
end;

procedure TForm1.TrayClick(Sender: TObject);
begin
  Show;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose:=mrYes=MessageDlg('��������� ������?', mtWarning, [mbYes, mbCancel], 0);
  if CanClose then
    core.Jab.tcp.Active:=false;
end;

procedure TForm1.IncClients;
begin
  cs.Enter;

  ClientCount:=core.Jab.tcp.Contexts.Count;

  //Inc(ClientCount);
  UpdateGui(true);

  cs.Leave;
end;

procedure TForm1.InitTrayIcon;
begin
 TrayIcon:= TTextTrayIcon.Create(Self);
 //TrayIcon.PopupMenu     := pm;
 TrayIcon.OnClick       := TrayClick;    // ��������� ������� ����������� ballon-hint
 TrayIcon.MinimizeToTray:= true;       // ������������ � ����
 TrayIcon.IconVisible   := true;       // ��� �����
 TrayIcon.Text          := 'X';        // ����������� ���������-�����
 TrayIcon.Color         := RGB(0,0,0); // ���� ���� ������
 TrayIcon.Font.Name     := 'arial';    // ����� ������ � ����
 TrayIcon.Font.Size     := 10;          // ������
 TrayIcon.Font.Color    := RGB(255,255,255); // ���� ������ � ������
end;

procedure TForm1.serv_Disconnect(AContext: TIdContext);
begin
  TJabberServerSession(AContext.Data).Free;
  AContext.Data:=nil;//TObject(1);
end;

function TForm1.TempEmojiHexToSmb(sHex: string): RawByteString;
begin              //reverse(not full) of JS function emojiReplace from http://st1.vk.me/js/al/emoji.js

  Result :='';
    //Char(StrToInt('$'+sHex)/$10000)+Char(StrToUint('$'+sHex) mod $10000);
end;

function TForm1.TempEmojiImgToDec(sImg: string): string;
var
  smb: RawByteString;
begin
  sImg:=ReplaceStr(sImg, '.png', '');
  smb:=TempEmojiHexToSmb(Trim(sImg));
  Result := UnicodeToAnsiEscape(smb);
end;

procedure TForm1.TempEmojiPack;
var
  I: Integer;
  sl: TStringList;
begin
  sl:=TStringList.Create;
  sl.LoadFromFile('theme');
  for I := 0 to sl.Count do
    sl.Strings[i]:=sl.Strings[i]+#9+TempEmojiImgToDec(sl.Strings[i]);

  sl.Free;
end;

procedure TForm1.Test1;
var
  msg: TGateMessage;
  s: string;
  vk: TVkClientSession;
  xml: TjanXMLParser2;
begin

    xml:=TjanXMLParser2.Create;
    xml.xml:='<stream:stream to=''vkxmpp.hopto.org'' xmlns=''jabber:client'' xmlns:stream=''http://etherx.jabber.org/streams'' version=''1.0''>' ;

  EXIT;

  s:=HttpMethodSSL(
    'https://api.vk.com/method/friends.get.xml?v=3.0&fields=uid,first_name,last_name&access_token=215731e5a389596491729c1768e3ab6dd21838955bfdd54465e10e88a1d55721a2884d3df7b2fc9170947'
    );

  ShowMessage(s);


  {
  serv := TIDExplicitTLSServer.Create();
  serv.OnExecute:=serv_Execute;}


  EXIT;

  vk:=TVkClientSession.Create(nil);
  //vk.NewAccessToken('https://oauth.vk.com/blank.html#code=46692d4cb88a9b2242');
	//vk.Token:=


  TestSendMessage(vk);
end;

procedure TForm1.Test2;
var
  sl: TStringList;
begin
  sl:=TStringList.Create;
  sl.LoadFromFile('c:\Downloads\messages.get.xml');
  sl.Text:=UnicodeToAnsiEscape(sl.Text);
  sl.Free;
end;

procedure TForm1.TestSendMessage(vk: TVkClientSession);
var
  msg: TGateMessage;
begin
   Msg:=TGateMessage.Create;
  msg.sTo:='6218430';
  msg.sBody:='����';
  vk.SendMessage(msg);
end;

procedure TForm1.TimerTimer(Sender: TObject);
begin
  RestartIfNeeded(core.ServName);
end;

procedure TForm1.UpdateGui(bInform: boolean);
var
  sDbg: string;
begin

  sDbg:=IfThen(isDbg, 'DBG', '');
  Caption:=Format('v.%s %s ���������� ��������: %d ����������: %d ����: %d',
    [SERVER_VER, sDbg, ClientCount, core.Jab.tcp.Contexts.Count, core.Jab.DefaultPort]);
  Application.Title:=Format('%d - XMPPGate', [ClientCount]);
  TrayIcon.Text:=IntToStr(ClientCount);

  if bInform and cbShowTrayBalloons.Checked then
    TrayIcon.ShowBalloonHint(' ',Caption, bitInfo, 10);
end;

function TForm1.UTF8BytesToString(bytes: TIdBytes): string;
begin
    SetLength(bytes, Length(bytes)+1);
    bytes[Length(bytes)]:=Byte(0);

    Result := UTF8ToString(PAnsiChar(bytes));
end;

end.
