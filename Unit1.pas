unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, IdContext, IdBaseComponent, IdComponent, IdCustomTCPServer,
  IdTCPServer, Vcl.StdCtrls, IdGlobal, IdExplicitTLSClientServerBase,
  VKClientSession, GateCore, TextTrayIcon;

type
  TForm1 = class(TForm)
    cbShowTrayBalloons: TCheckBox;
    procedure FormDestroy(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure TrayClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure serv_Disconnect(AContext: TIdContext);
  private
    bConnected: Boolean;
    bPsiOrder: Boolean;
    core: TGateCore;
    FClientCount: Integer;
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
    procedure Test1;
    function UTF8BytesToString(bytes: TIdBytes): string;
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  IdTCPClient, System.DateUtils, IdSSL, System.StrUtils, JabberServerSession,
  GateGlobals, uvsDebug, CoolTrayIcon, GateXml;

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
  dec(FClientCount);
  UpdateGui(false);
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  bTerminate:=true;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  isDbg:=false;
  //isDbg:=true;
  //bFakes:=true;


  if not isDbg then
    bFakes:=false;

  xmlForm:=Self;
  Application.OnException:=AppException;

  if isDbg then
    Test1;

  InitTrayIcon;
  Application.ShowMainForm:=false;

    try
      core:=TGateCore.Create(nil);
      core.IncClients:=IncClients;
      core.DecClients:=DecClients;
    finally
      UpdateGui(false);
    end;
end;

procedure TForm1.AppException(Sender: TObject; E: Exception);
begin
   //Socket Error # 10060 Connection timed out
   //if Pos('10060', e.Message)<>0 then

   AddToLog(e.Message);
end;

procedure TForm1.TrayClick(Sender: TObject);
begin
  Show;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose:=mrYes=MessageDlg('Завершить сервер?', mtWarning, [mbYes, mbCancel], 0);
end;

procedure TForm1.IncClients;
begin
  inc(FClientCount);
  UpdateGui(true);
end;

procedure TForm1.InitTrayIcon;
begin
 TrayIcon:= TTextTrayIcon.Create(Self);
 //TrayIcon.PopupMenu     := pm;
 TrayIcon.OnClick       := TrayClick;    // назначаем событие отображения ballon-hint
 TrayIcon.MinimizeToTray:= true;       // минимизируем в трей
 TrayIcon.IconVisible   := true;       // вкл показ
 TrayIcon.Text          := 'X';        // изначальное состояние-текст
 TrayIcon.Color         := RGB(0,0,0); // цвет фона иконки
 TrayIcon.Font.Name     := 'arial';    // шрифт текста в трее
 TrayIcon.Font.Size     := 10;          // размер
 TrayIcon.Font.Color    := RGB(255,255,255); // цвет текста в иконке
end;

procedure TForm1.serv_Disconnect(AContext: TIdContext);
begin
  TJabberServerSession(AContext.Data).Free;
  AContext.Data:=nil;//TObject(1);
end;

procedure TForm1.Test1;
var
  msg: TGateMessage;
  s: string;
  vk: TVkClientSession;
  xml: TGateXmlParser;
begin

    xml:=TGateXmlParser.Create;
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

procedure TForm1.TestSendMessage(vk: TVkClientSession);
var
  msg: TGateMessage;
begin
   Msg:=TGateMessage.Create;
  msg.sTo:='6218430';
  msg.sBody:='фыва';
  vk.SendMessage(msg);
end;

procedure TForm1.UpdateGui(bInform: boolean);
var
  sDbg: string;
begin
  sDbg:=IfThen(isDbg, 'DBG', '');
  Caption:=Format('v.%s %s Подключено клиентов: %d', [SERVER_VER, sDbg, FClientCount]);
  Application.Title:=Format('%d - XMPPGate', [FClientCount]);
  TrayIcon.Text:=IntToStr(FClientCount);

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
