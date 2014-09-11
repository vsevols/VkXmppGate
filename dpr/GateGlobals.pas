unit GateGlobals;

interface

uses
  System.Generics.Collections, System.RegularExpressions, System.Classes, System.SyncObjs, janXMLparser2;

type
  TObjProc = procedure of object;
  TVxCard = class;
  TVxCard = class(TComponent)
    function Duplicate(AOwner: TComponent): TVxCard;
  public
    sUrl: string;
    sPhotoUrl: string;
  end;

  TGateMessage = class(TComponent)
  private
  public
    sId: string;
    sBody: string;
    sFrom: string;
    sTo: string;
    dt: TDateTime;
    sType: string;
    constructor Create(AOwner: TComponent = nil); override;
    function Duplicate: TGateMessage;
    function Reply(sBody: string): TGateMessage;
    class function UrlEncode(Str: AnsiString): AnsiString;
  end;

  TGateStorage = class(TComponent)
    private
      FPath: string;
      procedure SetPath(const Value: string);
  public
      constructor Create(AOwner: TComponent);
      function LoadValue(const sName: string): string;
      function ReadInt(const sName: string; nDefault: Integer = 0): integer;
      procedure SaveValue(const sName, sVal: string);
      procedure WriteInt(const sName: string; nVal: Integer);
      property Path: string read FPath write SetPath;
  end;

  TFriendPresence = (fp_offline, fp_online);


  TFriend = class;

  TFriendList = class(TObjectList<TFriend>)

  private
  public
    function FindByAddr(sAddr: string): TFriend;
  end;

  TFriend = class(TComponent)
  public
    sAddr: string;
    sFullName: string;
    sGroup: string;
    Presence: TFriendPresence;
    vCard: TVxCard;
    IsMobile: boolean;
    AppId: string;
    constructor Create(AOwner: TComponent = nil);
    function Duplicate: TFriend;
  end;





  TLogProc = procedure(const str: string) of object;
  TVkApiCallFmt = function (const sMethod, sParams: string; args: array of const;
        slPost: TStringList = nil):TjanXMLParser2 of object;
  TVoidObjProc = procedure of object;


function FriendFind(search: TFriendList; sAddr: string): Integer;

function FriendsCopy(friends: TFriendList): TFriendList;

function HttpMethodSSL(sUrl: string; slPost: TStringList = nil; bSsl: boolean =
    true; AResponseStream: TStream = nil): string;

function HttpMethodSSL_Synapse(sUrl: string; slPost: TStringList = nil): string;

function Utf8StreamToString(Stream : TStream): String;

function XmlEscape(str: string; bDirection: boolean; bFromVk: boolean = false):
    string;

function AbsPath(const sRelative: string): string;

function GetRxGroup(str, sRegExpr: string; nGroup: Integer): string;

procedure RestartIfNeeded(sServerName: string);

procedure GateLog(const str: string);

function GetRxMatchGroup(collMatch: TMatchCollection; nGroup, nMatch: Integer):
    string;

function RestartServer(gs: TGateStorage; slPids: TStringList; sServerName,
    sLog: string): Boolean;

function IsOnlineMessageTime(dt: TDateTime): Boolean;

function UnicodeToAnsiEscape(textString: string): AnsiString;

function HttpMethodRawByte(sUrl: string; bSsl: boolean; slPost: TStringList =
    nil): RawByteString;

const
  CR = #$d#$a;
  SERVER_VER = '1121E5.8';

  SUPPORTNAME='__XmppGate-Support';

var
  sDbgSend:string;
  bTerminate:boolean;
  gcs: TCriticalSection;
  csRestart: TCriticalSection;
  bLongPollLog: boolean;
  bXmppLog: boolean;
  bVkApiLog: boolean;
  bCannotRestart: boolean; //prevents cyclic Logging
  ClientCount: Integer;

implementation

uses
  System.SysUtils, IdHTTP, IdSSLOpenSSL, httpsend, ssl_openssl, Vcl.Dialogs,
  IdURI, Vcl.Forms, SHellApi, Windows, uvsDebug, System.DateUtils;

function FriendFind(search: TFriendList; sAddr: string): Integer;
var
  I: Integer;
begin
  Result := -1;

  for I := 0 to search.Count-1 do
    if search[i].sAddr=sAddr then
    begin
      Result:=i;
      exit;
    end;
end;

function FriendsCopy(friends: TFriendList): TFriendList;
var
  i: Integer;
begin
  Result := TFriendList.Create(true);
  for i := 0 to friends.Count-1 do
  begin
    Result.Add(friends[i].Duplicate);
  end;
end;

function HttpMethodSSL(sUrl: string; slPost: TStringList = nil; bSsl: boolean =
    true; AResponseStream: TStream = nil): string;
var
  IdHTTP1: TIdHttp;
  IdSSLIOHandlerSocket1: TIdSSLIOHandlerSocketOpenSSL;
  ssResp: TStringStream;
begin
  IdHTTP1:=TIdHTTP.Create;

  if bSsl then
  begin
    IdSSLIOHandlerSocket1:=TIdSSLIOHandlerSocketOpenSSL.Create(IdHTTP1);
    IdHTTP1.IOHandler:= IdSSLIOHandlerSocket1;
  end;
  //IdSSLIOHandlerSocket1.SSLOptions.Method:= sslvSSLv2;
  //IdSSLIOHandlerSocket1.SSLOptions.Mode := sslmUnassigned;

//IdHTTP1.Host := sHost;
  //IdHTTP1.Port := 443;
{  IdHTTP1.HandleRedirects := True;
  IdHTTP1.Request.ContentType := 'text/html';
  IdHTTP1.Request.Accept := 'text/html, */*';
  IdHTTP1.Request.BasicAuthentication := False;
  IdHTTP1.Request.UserAgent := 'Mozilla/4.0 (compatible; MSIE 6.0; MSIE 5.5;) ';
}
  ssResp:=TStringStream.Create;
  try
    if not Assigned(slPost) then
    begin
      if not Assigned(AResponseStream) then
      begin
        IdHTTP1.Get(sUrl, ssResp);
        Result:=Utf8StreamToString(ssResp);
      end
        else
          IdHTTP1.Get(sUrl, AResponseStream);
    end
      else
      begin
        if not Assigned(AResponseStream) then
        begin
          IdHTTP1.Post(sUrl, slPost, ssResp);
          Result:=Utf8StreamToString(ssResp);
        end
          else
            IdHTTP1.Post(sUrl, slPost, AResponseStream);
      end;

  finally
    IdHTTP1.Free;
    ssResp.Free;
  end;

end;

function Utf8StreamToString(Stream : TStream): String;
var ms : TMemoryStream;
  rbUtf: RawByteString;
begin
  Result := '';
  ms := TMemoryStream.Create;
  try
    ms.LoadFromStream(Stream);
    SetString(rbUtf,PAnsiChar(ms.memory),ms.Size);
    Result:=UTF8ToUnicodeString(rbUtf);
  finally
    ms.free;
  end;
end;

function HttpMethodSSL_Synapse(sUrl: string; slPost: TStringList = nil): string;
var
  http: THttpSend;
  sHost: string;
  uri: TIdURI;
begin
  http:=THTTPSend.Create;
  http.Sock.CreateWithSSL(TSSLOpenSSL);

  uri:=TIdURI.Create(sUrl);
  sHost:=uri.Host;
  uri.Free;

  http.Sock.Connect(sHost, '443');
  http.Sock.SSLDoConnect;

  if not Assigned(slPost) then
  begin
    if http.HTTPMethod('GET', sUrl) then
      Result:=Utf8StreamToString(http.Document);
  end
    else
    begin
      slPost.Delimiter:='&';
      http.MimeType := 'application/x-www-form-urlencoded';
      http.Document.Write(Pointer(slPost.DelimitedText)^, Length(slPost.DelimitedText));
      if http.HTTPMethod('POST', sUrl) then
        Result:=Utf8StreamToString(http.Document);
    end;

  http.Free;
end;

function StringReplace(const str, sA, sB: string; bDirection: boolean): string;
begin
  if bDirection then
    Result := System.SysUtils.StringReplace(str, sA, sB, [rfIgnoreCase, rfReplaceAll])
    else
      Result := System.SysUtils.StringReplace(str, sB, sA, [rfIgnoreCase, rfReplaceAll])
end;

function XmlEscape(str: string; bDirection: boolean; bFromVk: boolean = false):
    string;
begin
  str := StringReplace(str,'&', '&amp;', bDirection);

  str := StringReplace(str,'<', '&lt;', bDirection);
  str := StringReplace(str,'>', '&gt;', bDirection);

  {if not bDirection then
  begin
  str := StringReplace(str,'&', '&amp;', bDirection);
    str := StringReplace(str,'''', '&#39;', bDirection);
  end;}

  str := StringReplace(str,'"', '&quot;', bDirection);
  str := StringReplace(str,'''', '&apos;', bDirection);

  if bFromVk then
  begin
    str := StringReplace(str, CR,'<br>', bDirection);
    str := StringReplace(str, CR,'<br/>', bDirection);
    str := StringReplace(str,'&', '&amp;', bDirection); //double escape for &amp in VK
    //seems like vkontakte changes this behaviour from time to time :)
    // TODO: ? Extract to config?

    str := StringReplace(str,'''', '&#39;', bDirection);
  end;


  Result := str;
end;

function AbsPath(const sRelative: string): string;
begin
  Result := ExtractFilePath(Application.ExeName)+sRelative;
end;

function GetRxMatchGroup(collMatch: TMatchCollection; nGroup, nMatch: Integer):
    string;
var
  rx: TRegEx; //TODO: merge with GetRxGroup
begin
  Result:='';


  if (collMatch.Count>nMatch) then
  begin
    if nGroup<collMatch.Item[nMatch].Groups.Count then
    Result:=collMatch.Item[nMatch].Groups.Item[nGroup].Value;
  end;
end;

function RestartServer(gs: TGateStorage; slPids: TStringList; sServerName,
    sLog: string): Boolean;
var
  sCmdLine: string;
begin
  Result:=false;

  if not FileExists(Application.ExeName) then
  begin
    if not bCannotRestart then
      GateLog('Cannot restart. No EXE file');

    if not Assigned(gs) then
      MessageDlg('Cannot restart. No EXE file', mtError, [mbOK], 0);

    bCannotRestart:=true;
    exit;
  end;

  if sLog<>'' then
    GateLog(sLog);

  sCmdLine:='-killpid '+IntToStr(GetCurrentProcessId);

  if sServerName<>'' then
    sCmdLine:=sCmdLine+' -servname '+sServerName;

  csRestart.Enter; //prevent several processes creating
  GateLog('csRestart entered');

  if Assigned(gs) then
    gs.SaveValue('restartPids', slPids.Text);

  GateLog('before ShellExecute');
  Result:=32<ShellExecute(0, 'open', pChar(Application.ExeName),
    pChar(sCmdLine), nil, SW_SHOWNORMAL);

  GateLog('after ShellExecute');

  //TODO: exit process by normal way

end;

procedure RestartIfNeeded(sServerName: string);
var
  gs: TGateStorage;
  I: Integer;
  slPids: TStringList;
begin
  gs:=TGateStorage.Create(nil);
  try
    //rstpid:=
    slPids:=TStringList.Create;
    slPids.Text:=gs.LoadValue('restartPids');

    for I := 0 to slPids.Count-1 do
    begin
      try
        if StrToInt(Trim(slPids.Strings[i]))=GetCurrentProcessId then
        begin
          slPids.Strings[i]:='0';
          RestartServer(gs, slPids, sServerName, 'Restarting by file command');
          break;
        end;
      except
      end;
    end;

  finally
    gs.Free;
  end;
end;

procedure GateLog(const str: string);
begin
  AddToLog(str);
end;

function GetRxGroup(str, sRegExpr: string; nGroup: Integer): string;
var
  rx: TRegEx;
begin
  Result:='';

  rx:=TRegEx.Create(sRegExpr);
  if rx.IsMatch(str) then
  begin
    if nGroup<rx.Match(str).Groups.Count then
    Result:=rx.Match(str).Groups.Item[nGroup].Value;
  end;
end;

function IsOnlineMessageTime(dt: TDateTime): Boolean;
begin
  Result:=
    (dt=0)
      or
    (MinutesBetween(TTimeZone.Local.ToLocalTime(dt), Now)<2);
end;

function UnicodeToAnsiEscape(textString: string): AnsiString;
var
  b: Cardinal;
  haut: Cardinal;
  i: Integer;
  outputString: string;
begin                    //translated from JS function convertChar2CP
                          //http://www.sceneonthe.net/unicode.htm

  outputString := '';
  haut := 0;
  for i:=1 to textString.length do
  begin
    b:=Ord(textString[i]);
    if (b > $FFFF) then
    begin
      outputString := outputString+'!error: ' + IntToHex(b,0) + '!';
    end;

    if haut<>0 then
    begin
      if ($DC00 <= b) and (b <= $DFFF)  then
      begin
        outputString := outputString+'&#'+UIntToStr($10000 + ((haut - $D800) shl 10) + (b - $DC00)) + ';';
        haut := 0;
        continue;
      end
      else
      begin
        outputString := outputString+'!error: ' + IntToHex(haut,0) + '!';
        haut:=0;
      end;
    end;

    if ($D800 <= b) and (b <= $DBFF) then
      haut:=b
      else
      begin
        if (AnsiString(textString[i])='?') and (Ord(textString[i])<>63) then
          outputString := outputString+'&#'+ UIntToStr(b) + ';'
          else
            outputString := outputString + textString[i];
      end;

  end;
  Result:=outputString;

end;

function HttpMethodRawByte(sUrl: string; bSsl: boolean; slPost: TStringList =
    nil): RawByteString;
var
  ss: TStringStream;
begin
  Result := '';

  ss:=TStringStream.Create;
  try
   HttpMethodSSL(sUrl, nil, false, ss);
   Result := ss.DataString;
  finally
    ss.Free;
  end;
end;


constructor TGateMessage.Create(AOwner: TComponent = nil);
begin
  inherited;
  // TODO -cMM: TGateMessage.Create default body inserted
end;

function TGateMessage.Duplicate: TGateMessage;
begin
  Result := TGateMessage.Create(nil);
  Result.sId:=sId;
  Result.sBody:=sBody;
  Result.sFrom:=sFrom;
  Result.sTo:=sTo;
  Result.sType:=sType;
  Result.dt:=dt;
end;

function TGateMessage.Reply(sBody: string): TGateMessage;
var
  sTmp: string;
begin
  Result := Self.Duplicate;
  sTmp := Result.sFrom;
  Result.sFrom := Result.sTo;
  Result.sTo := sTmp;
  Result.sBody:=sBody;
end;

class function TGateMessage.UrlEncode(Str: AnsiString): AnsiString;
function CharToHex(Ch: AnsiChar): Integer;
 asm
    and eax, 0FFh
    mov ah, al
    shr al, 4
    and ah, 00fh
    cmp al, 00ah
    jl @@10
    sub al, 00ah
    add al, 041h
    jmp @@20
@@10:
    add al, 030h
@@20:
    cmp ah, 00ah
    jl @@30
    sub ah, 00ah
    add ah, 041h
    jmp @@40
@@30:
    add ah, 030h
@@40:
    shl eax, 8
    mov al, '%'
end;

var
 i, Len: Integer;
 Ch: AnsiChar;
 N: Integer; P: PAnsiChar;
begin
 Result:='';
 Len:=Length(Str);
 P:=PAnsiChar(@N);
 for i:=1 to Len do begin
  Ch:=Str[i];
  if Ch in ['0'..'9', 'A'..'Z', '.', 'a'..'z', '_'] then Result:=Result+Ch else begin
   if Ch = ' ' then Result:=Result+'+' else begin
    N:=CharToHex(Ch);
    Result:=Result+P;
   end;
  end;
 end;
end;

constructor TFriend.Create(AOwner: TComponent = nil);
begin
  inherited Create(AOwner);
  Self.sGroup:='VkXmppGate';
  vCard := TVxCard.Create(Self);
end;

function TFriend.Duplicate: TFriend;
// TODO: ?memleak: May be there is implicit copying of TFriend when
// calling TFriendList.Add ?
begin
  Result := TFriend.Create;
  Result.sAddr:=sAddr;
  Result.sFullName:=sFullName;
  Result.Presence:=Presence;
  Result.sGroup:=sGroup;
  Result.VCard:=VCard.Duplicate(Result);
  Result.IsMobile:=IsMobile;
  Result.AppId:=AppId;
end;

constructor TGateStorage.Create(AOwner: TComponent);
begin
  inherited;
  Path:=AbsPath('');
end;

function TGateStorage.LoadValue(const sName: string): string;
var
  sl: TStringList;
begin
  sl:=TStringList.Create;
  try
    sl.LoadFromFile(Path+sName+'.txt');
    Result:=Trim(sl.Text);
  except
    Result:='';
  end;
  sl.Free;
end;

function TGateStorage.ReadInt(const sName: string; nDefault: Integer = 0):
    integer;
begin
  Result:=nDefault;

  try
    Result := StrToInt(Trim(LoadValue(sName)));
  except
  end;
end;

procedure TGateStorage.SaveValue(const sName, sVal: string);
var
  sl: TStringList;
begin
  if (Pos('\',sNAme)>0 )or (Pos('/',sNAme)>0) then
    ForceDirectories(FPath+ExtractFilePath(sName));

  sl:=TStringList.Create;
  sl.Text:=sVal;
  try
    sl.SaveToFile(FPath+sName+'.txt');
  except
  end;
  sl.Free;
end;

procedure TGateStorage.SetPath(const Value: string);
begin
  FPath := IncludeTrailingPathDelimiter(Value);
  ForceDirectories(FPath);
end;

procedure TGateStorage.WriteInt(const sName: string; nVal: Integer);
begin
  SaveValue(sName, IntToStr(nVal));
end;

function TFriendList.FindByAddr(sAddr: string): TFriend;
var
  I: Integer;
begin
  Result:=nil;

  for I := 0 to Count-1 do
    if Self.Items[i].sAddr=sAddr then
    begin
      Result:=Self.Items[i];
      exit;
    end;
end;

function TVxCard.Duplicate(AOwner: TComponent): TVxCard;
begin
  Result := TVxCard.Create(AOwner);
  Result.sUrl := Self.sUrl;
  Result.sPhotoUrl := Self.sPhotoUrl;
end;


initialization
  gcs:=TCriticalSection.Create;
  csRestart:=TCriticalSection.Create;
finalization
  FreeAndNil(gcs);


end.
