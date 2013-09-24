unit GateCore;

interface

uses
  IdContext, System.Classes, JabberServer, JabberServerSession;

type
  TObjProc = procedure of object;

  TGateCore = class(TComponent)
  private
    FDecClients: TObjProc;
    FIncClients: TObjProc;
    FLog: TStrings;
    procedure OnSessionDestroy(AJabSession: TJabberServerSession);
  public
    Jab: TJabberServer;
    constructor Create(ALog: TStrings);
    procedure Init;
    procedure Log(const str: string);
    procedure OnNewSession(AJabSession: TJabberServerSession);
    property DecClients: TObjProc read FDecClients write FDecClients;
    property IncClients: TObjProc read FIncClients write FIncClients;
  end;

implementation

uses
  VKtoXMPPSession, uvsDebug;

constructor TGateCore.Create(ALog: TStrings);
begin
  FLog:=ALog;
  Init;
end;

procedure TGateCore.Init;
begin
  InitVsDbg(isDbg, true, AbsPath('log\'));
  Jab := TJabberServer.Create(Self);
  Jab.OnSessionCreate:=OnNewSession;
  Jab.OnSessionDestroy:=OnSessionDestroy;
  Jab.Activate;
  //dbg
  //VK := TVKClient.Create(Self);
end;

procedure TGateCore.Log(const str: string);
begin
  AddToLog(str);
  exit;
  //FLog.Add(str);  //TODO: крит. секция
end;

procedure TGateCore.OnSessionDestroy(AJabSession: TJabberServerSession);
begin
  if Assigned(@FDecClients) then
  begin
    cs.Enter;
    FDecClients;
    cs.Leave;
  end;
end;

procedure TGateCore.OnNewSession(AJabSession: TJabberServerSession);
begin
  TVKtoXmppSession.Create(AJabSession).OnLog:=Log;
  if Assigned(@FIncClients) then
  begin
    cs.Enter;
    FIncClients;
    cs.Leave;
  end;
end;

end.

