unit VkLongPollClient;

interface

uses
  System.Classes, GateGlobals, IdHttp, IdGlobal, System.SyncObjs;

type
  TLongPollStream = class;
  TVkLongPollClient = class(TThread)
  private
    FOnEvent: TVoidObjProc;
    FOnLog: TLogProc;
    Key: string;
    OnNewServerNeeded: TVoidObjProc;
    Owner: TComponent;
    pollStream: TLongPollStream;
    Server: string;
    tcp: TIdHttp;
    Ts: string;
    procedure ClearServer;
    procedure Connect;
    function JsonErrorCheck(sJson: string): Boolean;
    procedure KeepConnected;
    procedure RetrieveServerParams;
    procedure SetOnEvent(const Value: TVoidObjProc);
    procedure SetOnLog(const Value: TLogProc);
  public
    cs: TCriticalSection;
    //OnLog: TLogProc;
    VkApiCallFmt: TVkApiCallFmt;
    OnTyping: procedure(sUid:string) of object;
    constructor Create(bSuspended: Boolean);
    destructor Destroy; override;
    procedure Execute; override;
    function Parse(sJson: string): boolean;
    property OnLog: TLogProc read FOnLog write SetOnLog;
    property OnEvent: TVoidObjProc read FOnEvent write SetOnEvent;
  end;

  TLongPollStream = class(TMemoryStream)
    OnWrite : function(sData: string): boolean of object;
    function Write(const Buffer; Count: Longint): Longint; override;
  private
  public
  end;

implementation

uses
  janXMLparser2, vkApi, System.SysUtils;

constructor TVkLongPollClient.Create(bSuspended: Boolean);
begin
  inherited;
  owner:=TComponent.Create(nil);
  cs := TCriticalSection.Create();
  tcp:=TIdHttp.Create(owner);
  pollStream:=TLongPollStream.Create;
  pollStream.OnWrite:=Parse;
end;

destructor TVkLongPollClient.Destroy;
begin
  FreeAndNil(cs);
  FreeAndNil(owner);
  FreeAndNil(pollStream);
  inherited Destroy;
end;

procedure TVkLongPollClient.ClearServer;
begin
  Server:='';
end;

procedure TVkLongPollClient.RetrieveServerParams;
var
  par: TjanXMLParser2;
begin
  par:=VkApiCallFmt('messages.getLongPollServer', '', []);
  try
    if (par.rootNode.getChildByName('key')<>nil)
      and
      (par.rootNode.getChildByName('server')<>nil)
      and
      (par.rootNode.getChildByName('ts')<>nil)
      then
        begin
          Key:=par.rootNode.getChildByName('key').text;
          Server:=par.rootNode.getChildByName('server').text;
          Ts:=par.rootNode.getChildByName('ts').text;
          exit;
        end;
    raise EVkApiParse.Create('RetrieveServerParams error');
  finally
    FreeAndNil(par);
  end;
end;

procedure TVkLongPollClient.KeepConnected;
begin
  //if not tcp.Connected then
    Connect;
end;

procedure TVkLongPollClient.Connect;
var
  sUrl: string;
begin
  if Server='' then
    RetrieveServerParams;    //TODO: Check syntax { failed: 2 }

  sUrl:=Format('http://%s?act=a_check&key=%s&ts=%s&wait=25&mode=2',
    [Server, key, ts]);

  if bLongPollLog then
    OnLog('TVkLongPollClient GET: '+sUrl);

  tcp.Get(sUrl, pollStream);
end;

procedure TVkLongPollClient.Execute;
begin
  while not Terminated do
  begin
    try
      KeepConnected;
    except     {
    on e: EVkApi do
    begin
      if e.Error=10014 then // don't garbage log file by cyclic exceptions
        Sleep(10000)
      else
        if Assigned(OnLog) then
          OnLog(e.Message);
    end;        }
    on e: Exception do
    begin
      if Assigned(OnLog) then
        OnLog(e.Message);
      Sleep(30000);
    end;
    end;
  end;
  OnLog('LongPoll Terminated');
end;

function TVkLongPollClient.JsonErrorCheck(sJson: string): Boolean;
begin
  Result:=true;

  if Pos('failed', sJson)>0 then
    Result:=false;
end;

function TVkLongPollClient.Parse(sJson: string): boolean;
var
  sTypingId: string;
begin
  Result:=true;

  if bLongPollLog and Assigned(OnLog) then
    OnLog('TVkLongPollClient RECV: '+sJson);

  if JsonErrorCheck(sJson) then
  begin
    if Pos('[4,', sJson)>0 then
      try
        cs.Enter;
        OnEvent;
      finally
        cs.Leave;
      end;

    sTypingId:=GetRxGroup(sJson, '61,(-{0,1}\d*?),', 1);
    if sTypingId<>'' then
      if Assigned(OnTyping) then
        try
          cs.Enter;
          OnTyping(sTypingId);
        finally
          cs.Leave;
        end;

    Ts:=GetRxGroup(sJson, '"ts":(\d*?),', 1);
  end
    else Ts:='';

  if Ts='' then
      Server:='';
end;

procedure TVkLongPollClient.SetOnEvent(const Value: TVoidObjProc);
begin
  FOnEvent := Value;
end;

procedure TVkLongPollClient.SetOnLog(const Value: TLogProc);
begin
  FOnLog := Value;
end;


function TLongPollStream.Write(const Buffer; Count: Longint): Longint;
var
  sJson: string;
begin
  Result := inherited Write(Buffer, Count);
  sJson:=Utf8StreamToString(Self);

  if Assigned(OnWrite) then
    if OnWrite(sJson) then
      Clear;
end;

end.
