unit JabberServer;

// (C) Vsevols 18.09.2013
// http://vsevols.livejournal.com
// vsevols@gmail.com

interface

uses
  IdExplicitTLSClientServerBase, IdContext, System.Classes,
  JabberServerSession, IdTCPServer, System.SysUtils, GateGlobals;

type
  TJabberServer = class(TComponent)
    procedure Execute(AContext: TIdContext);
  private
    FActive: Boolean;
    FDefaultPort: Integer;
    procedure SetActive(const Value: Boolean);
    procedure SetDefaultPort(const Value: Integer);
  public
    OnSessionCreate: procedure(AJabSession: TJabberServerSession) of object;
    OnSessionDestroy: procedure(AJabSession: TJabberServerSession) of object;
    //tcp: TIDExplicitTLSServer;
    tcp: TIdTcpServer;
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;
    procedure InternalOnConnect(AContext: TIdContext);
    procedure InternalOnDisconnect(AContext: TIdContext);
    procedure OnTcpException(AContext: TIdContext; AException: Exception);
    property Active: Boolean read FActive write SetActive;
    property DefaultPort: Integer read FDefaultPort write SetDefaultPort;
  end;

implementation

uses
  IdGlobal, IdSSL, uvsDebug, Vcl.Forms;

constructor TJabberServer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  //tcp:=TIDExplicitTLSServer.Create(Self);
  tcp:=TIdTcpServer.Create(Self);
  tcp.OnException:=OnTcpException;
  DefaultPort:=5222;
  //tcp.MaxConnections:=200;

  tcp.DefaultPort:=DefaultPort;

  tcp.OnExecute:=Execute;
  tcp.OnDisconnect:=InternalOnDisconnect;
  tcp.OnConnect:=InternalOnConnect;

  //if (tcp.IOHandler is TIdSSLIOHandlerSocketBase) then begin
    //  (tcp.IOHandler as TIdSSLIOHandlerSocketBase).PassThrough := False;
end;

destructor TJabberServer.Destroy;
begin
  inherited Destroy;
end;

procedure TJabberServer.Execute(AContext: TIdContext);
var
  bTls: Boolean;
  buf: TIdBytes;
  ses: TJabberServerSession;
  s: string;
begin
  if not Assigned(AContext.Data) then
  begin
    GateLog(Format('Execute() Context %s Creating TJabberServerSession',
      [IntToHex(Cardinal(AContext), 8)]));
    ses:=TJabberServerSession.Create(AContext);

    if(Assigned(OnSessionCreate))then
      OnSessionCreate(ses);
  end;

  if Integer(AContext.Data)=-1 then
  begin
    GateLog('TJabberServer.Execute AContext.Data=-1');
    exit;
  end;

    TJabberServerSession(AContext.Data).InternalOnExecute();

end;

procedure TJabberServer.InternalOnConnect(AContext: TIdContext);
var
  buf: TIdBytes;
begin
  if false then //tcp.MaxConnections=tcp.Contexts.Count then
  begin
      buf:=TJabberServerSession.StringToUTF8Bytes('maxconnections exceeded');
      AContext.Connection.Socket.Write(buf);
      AContext.Connection.Disconnect;
  end;
end;

procedure TJabberServer.InternalOnDisconnect(AContext: TIdContext);
var
  jss: TJabberServerSession;
  sLogin: string;
begin
  if(Assigned(OnSessionDestroy))then
      OnSessionDestroy(TJabberServerSession(AContext.Data));

  try
    if not assigned(AContext.Data) then
      exit;

    if Integer(AContext.Data)=-1 then
    begin
      GateLog('TJabberServer.InternalOnDisconnect AContext.Data=-1');
      exit;
    end;

    GateLog(Format('InternalOnDisconnect Context %s Destroying TJabberServerSession',
      [IntToHex(Cardinal(AContext), 8)]));

    jss:=TJabberServerSession(AContext.Data);
    sLogin:=jss.sLogin;
    AContext.Data:=nil;
    jss.Terminate:=true; // does not make sense
    jss.Free;
    //TJabberServerSession(AContext.Data).Terminate:=true;
    //TJabberServerSession(AContext.Data).Free;
  except
    GateLog(Format('%s;InternalOnDisconnect exception', [sLogin]));
  end;
end;

procedure TJabberServer.OnTcpException(AContext: TIdContext; AException: Exception);
begin
  Application.OnException(AContext, AException);
end;

procedure TJabberServer.SetActive(const Value: Boolean);
begin
  if Value then
  begin
    tcp.Active:=Value;
    FActive := tcp.Active;
  end; //TODO: active=false
end;

procedure TJabberServer.SetDefaultPort(const Value: Integer);
begin
  FDefaultPort := Value;
  tcp.DefaultPort:=DefaultPort;
end;

end.
