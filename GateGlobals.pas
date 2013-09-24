unit GateGlobals;

interface

uses
  System.Generics.Collections, System.Classes, System.SyncObjs;

type
  TGateMessage = class(TObject)
  private
  public
    sId: string;
    sBody: string;
    sFrom: string;
    sTo: string;
    dt: TDateTime;
    function Duplicate: TGateMessage;
    function Reply(sBody: string): TGateMessage;
    class function UrlEncode(Str: AnsiString): AnsiString;
  end;

  TGateStorage = class(TComponent)
    private
      FPath: string;
      procedure SetPath(const Value: string);
  public
      function LoadValue(const sName: string): string;
      function ReadInt(const sName: string; nDefault: Integer = 0): integer;
      procedure SaveValue(const sName, sVal: string);
      procedure WriteInt(const sName: string; nVal: Integer);
      property Path: string read FPath write SetPath;
  end;

  TFriendPresence = (fp_offline, fp_online);


  TFriend = class;

  TFriendList = TObjectList<TFriend>;

  TFriend = class(TObject)
    sAddr: string;
    sFullName: string;
    sGroup: string;
    Presence: TFriendPresence;
  public
    function Duplicate: TFriend;
  end;





  TLogProc = procedure(const str: string) of object;

function FriendFind(search: TFriendList; sAddr: string): Integer;

function FriendsCopy(friends: TFriendList): TFriendList;

function HttpMethodSSL(sUrl: string; slPost: TStringList = nil): string;

function HttpMethodSSL_Synapse(sUrl: string; slPost: TStringList = nil): string;

function Utf8StreamToString(Stream : TStream): String;

function XmlEscape(str: string; bDirection: boolean; bBr: boolean = false):
    string;

function AbsPath(const sRelative: string): string;

const
  CR = #$d#$a;
  SERVER_VER = '0919F_alpha';

  SUPPORTNAME='____XmppGate-Support';

var
  sDbgSend:string;
  bTerminate:boolean;
  gcs: TCriticalSection;

implementation

uses
  System.SysUtils, IdHTTP, IdSSLOpenSSL, httpsend, ssl_openssl, Vcl.Dialogs,
  IdURI, Vcl.Forms;

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

function HttpMethodSSL(sUrl: string; slPost: TStringList = nil): string;
var                        // не используется
  IdHTTP1: TIdHttp;
  IdSSLIOHandlerSocket1: TIdSSLIOHandlerSocketOpenSSL;
begin
  IdHTTP1:=TIdHTTP.Create;
  IdSSLIOHandlerSocket1:=TIdSSLIOHandlerSocketOpenSSL.Create(IdHTTP1);
  IdHTTP1.IOHandler:= IdSSLIOHandlerSocket1;
  //IdSSLIOHandlerSocket1.SSLOptions.Method:= sslvSSLv2;
  //IdSSLIOHandlerSocket1.SSLOptions.Mode := sslmUnassigned;

//IdHTTP1.Host := sHost;
  //IdHTTP1.Port := 443;
{  IdHTTP1.HandleRedirects := True;
  IdHTTP1.Request.ContentType := 'text/html';
  IdHTTP1.Request.Accept := 'text/html, */*';
  IdHTTP1.Request.BasicAuthentication := False;
  IdHTTP1.Request.UserAgent := 'Mozilla/4.0 (compatible; MSIE 6.0; MSIE 5.5;) ';
  ms:=TMemoryStream.Create;
 }
  //ms:=TMemoryStream.Create;

  if not Assigned(slPost) then
    Result:=IdHTTP1.Get(sUrl)
    else
      Result:=IdHTTP1.Post(sUrl, slPost);

  IdHTTP1.Free;

  //ms.Free;
end;

function Utf8StreamToString(Stream : TStream): String;
var ms : TMemoryStream;
begin
  Result := '';
  ms := TMemoryStream.Create;
  try
    ms.LoadFromStream(Stream);
    SetString(Result,PAnsiChar(ms.memory),ms.Size);
    Result:=Utf8ToAnsi(Result);
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

function XmlEscape(str: string; bDirection: boolean; bBr: boolean = false):
    string;
begin
  str := StringReplace(str,'<', '&lt;', bDirection);
  str := StringReplace(str,'>', '&gt;', bDirection);
  str := StringReplace(str,'&', '&amp;', bDirection);
  str := StringReplace(str,'"', '&quot;', bDirection);

  if bBR then
  begin
    str := StringReplace(str, CR,'<br>', bDirection);
    str := StringReplace(str, CR,'<br/>', bDirection);
  end;


  Result := str;
end;

function AbsPath(const sRelative: string): string;
begin
  Result := ExtractFilePath(Application.ExeName)+sRelative;
end;


function TGateMessage.Duplicate: TGateMessage;
begin
  Result := TGateMessage.Create;
  Result.sId:=sId;
  Result.sBody:=sBody;
  Result.sFrom:=sFrom;
  Result.sTo:=sTo;
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

function TFriend.Duplicate: TFriend;
begin
  Result := TFriend.Create;
  Result.sAddr:=sAddr;
  Result.sFullName:=sFullName;
  Result.Presence:=Presence;
  Result.sGroup:=sGroup;
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


initialization
  gcs:=TCriticalSection.Create;
finalization
  FreeAndNil(gcs);


end.
