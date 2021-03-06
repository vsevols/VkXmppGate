unit GateCore;

interface

uses
  IdContext, System.Classes, JabberServer, JabberServerSession;

type
  TObjProc = procedure of object;

  TGateCore = class(TComponent)
    procedure KillPidIfNeeded;
  private
    FDecClients: TObjProc;
    FIncClients: TObjProc;
    FLog: TStrings;
    function GetCmdLineParam(sParam: string): string;
    procedure KillProcess(const lPID: Cardinal);
    procedure OnSessionDestroy(AJabSession: TJabberServerSession);
  public
    Jab: TJabberServer;
    ServName: string;
    constructor Create(ALog: TStrings);
    procedure Init;
    procedure Log(const str: string);
    procedure OnNewSession(AJabSession: TJabberServerSession);
    property DecClients: TObjProc read FDecClients write FDecClients;
    property IncClients: TObjProc read FIncClients write FIncClients;
  end;

implementation

uses
  VKtoXMPPSession, uvsDebug, GateGlobals, Vcl.Forms, System.SysUtils, Windows;

constructor TGateCore.Create(ALog: TStrings);
begin
  FLog:=ALog;
end;

function TGateCore.GetCmdLineParam(sParam: string): string;
var
  I: Integer;
begin
  Result:='';

  for I := 1 to ParamCount-1 do
    if ParamStr(I)=sParam then
    begin
      Result := ParamStr(I+1);
      break;
    end;
end;

procedure TGateCore.Init;
var
  gs: TGateStorage;
begin
  // calling separately of Create because here is a cycle
  // with ProcessMessages
  InitVsDbg(isDbg, true, AbsPath('log\'));
  Log('Starting '+SERVER_VER+' CmdLine: '+ CmdLine);


  KillPidIfNeeded;

  ServName:=GetCmdLineParam('-servname');

  gs:=TGateStorage.Create(Self);

  Jab := TJabberServer.Create(Self);
  Jab.OnSessionCreate:=OnNewSession;
  Jab.OnSessionDestroy:=OnSessionDestroy;
  Jab.DefaultPort:=gs.ReadInt('xmppPort', 5222);

  gs.Free;


  while not Jab.Active do
  begin
    try
      Jab.Active:=true;
    except on e:Exception do
      begin
        Log(e.Message);
        Application.ProcessMessages;
        Sleep(1000);
      end;
    end;
  end;

  Log('Port Bound: '+IntToStr(Jab.DefaultPort));

end;

procedure TGateCore.KillPidIfNeeded;
var
  lPID: Cardinal;
  sPid: string;
begin
  lPID:=0;


  sPid:=GetCmdLineParam('-killpid');

  if sPid='' then
  begin
    SetPriorityClass(GetCurrentProcess, BELOW_NORMAL_PRIORITY_CLASS);
    exit;
  end;

  if ParamStr(1)<>'-killpid' then
    exit;
  try
    lPID := StrToInt(sPid);
  except
  end;

  if lPid<1 then
  begin
    SetPriorityClass(GetCurrentProcess, BELOW_NORMAL_PRIORITY_CLASS);
    exit;
  end;

  KillProcess(lPID);
  //Sleep(10000);
end;

procedure TGateCore.KillProcess(const lPID: Cardinal);
var
  lCurrentProcPID: Cardinal;
  lProcHandle: Cardinal;
begin
  try
    lCurrentProcPID := GetCurrentProcessId;
    if (lPID <> INVALID_HANDLE_VALUE) and (lCurrentProcPID <> lPID) then
    begin
      lProcHandle := OpenProcess(PROCESS_TERMINATE, False, lPID);
      if lProcHandle=0 then
      begin
        GateLog('Nothing to kill');
        exit;
      end;

      GateLog('Process Exisits. KILLING PID '+IntToStr(lPID));


      Windows.TerminateProcess(lProcHandle, 0);
      WaitForSingleObject(lProcHandle, Infinite);
      CloseHandle(lProcHandle);
      //Result := True;
    end;
  except
    //raise EExternalException.Create(GetLastErrorString);
  end;
end;

procedure TGateCore.Log(const str: string);
begin
  (*TODO: extracted code
  AddToLog(str);
  *)
  GateLog(str);
  exit;
  //FLog.Add(str);  //TODO: ����. ������
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
var
  vxs: TVKtoXmppSession;
begin
  vxs:=TVKtoXmppSession.Create(AJabSession);
  vxs.OnLog:=Log;
  vxs.ServName:=ServName;

  if Assigned(@FIncClients) then
  begin
    cs.Enter;
    FIncClients;
    cs.Leave;
  end;
end;

end.

