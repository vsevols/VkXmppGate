unit JabberServer;

// (C) Vsevols 18.09.2013
// http://vsevols.livejournal.com
// vsevols@gmail.com

interface

uses
  IdExplicitTLSClientServerBase, IdContext, System.Classes,
  JabberServerSession, IdTCPServer, System.SysUtils;

type
  TJabberServer = class(TComponent)
    procedure Execute(AContext: TIdContext);
  private
    //tcp: TIDExplicitTLSServer;
    tcp: TIdTcpServer;
  public
    Port:integer;
    OnSessionCreate: procedure(AJabSession: TJabberServerSession) of object;
    OnSessionDestroy: procedure(AJabSession: TJabberServerSession) of object;
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;
    procedure Activate;
    procedure InternalOnDisconnect(AContext: TIdContext);
    procedure OnTcpException(AContext: TIdContext; AException: Exception);
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
  Port:=5222;

  if isDbg then
    Port:=5223;

  tcp.DefaultPort:=Port;

  tcp.OnExecute:=Execute;
  tcp.OnDisconnect:=InternalOnDisconnect;

  //if (tcp.IOHandler is TIdSSLIOHandlerSocketBase) then begin
    //  (tcp.IOHandler as TIdSSLIOHandlerSocketBase).PassThrough := False;
end;

destructor TJabberServer.Destroy;
begin
  inherited Destroy;
end;

procedure TJabberServer.Activate;
begin
  tcp.Active:=true;
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
    ses:=TJabberServerSession.Create(AContext);

    if(Assigned(OnSessionCreate))then
      OnSessionCreate(ses);
  end;

    TJabberServerSession(AContext.Data).InternalOnExecute();

end;

procedure TJabberServer.InternalOnDisconnect(AContext: TIdContext);
begin
  if(Assigned(OnSessionDestroy))then
      OnSessionDestroy(TJabberServerSession(AContext.Data));

  TJabberServerSession(AContext.Data).Free;
  AContext.Data:=nil;
end;

procedure TJabberServer.OnTcpException(AContext: TIdContext; AException: Exception);
begin
  Application.OnException(AContext, AException);
end;

end.
