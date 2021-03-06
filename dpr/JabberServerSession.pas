unit JabberServerSession;

// (C) Vsevols 2013
// http://vsevols.livejournal.com
// vsevols@gmail.com


interface

uses
  IdContext, IdTCPClient, System.Classes, IdGlobal, GateGlobals, janXMLparser2,
  windows, D7Compat, System.Generics.Collections;

type
  TJsStatus = (jsst_connecting, jsst_auth, jsst_authdone, jsst_online);
  TJsUserStatus = (just_online, just_away); //not used now. See PresShow
  TJabberServerSession = class;
  TJabberServerSession = class(TComponent)
    function GetUserPhotoSha1Hex(sJid, sPhotoUrl: string): string;
    function ProcessGetAvatar(sId, sTo: string): Boolean;
    function Sha1Hex(rb: RawByteString): string;
    function ToHex(rb: RawByteString): string;
  private
    AliveTestMethod: string;
    bAuth: Boolean;
    DBGbServer: Boolean;
    bTls: Boolean;
    FAliveTested: Boolean;
    FLastFriends: TFriendList;
    FOnPresShowChanged: TObjProc;
    FPresShow: string;
    MsgQueue: TObjectList<TGateMessage>;
    QueryClientVersionDone: Boolean;
    sBindId: string;
    sClientOs: string;
    sClientProgName: string;
    sClientVersion: string;
    StFriendsGlobal: TGateStorage;
    function DecodeBase64(const CinLine: D7String): D7String;
    procedure ProcessAuth(xml: TjanXMLNode2);
    procedure DoSasl(AContext: TIdContext);
    procedure DoTls(AContext: TIdContext);
    function GetBase64DataByUrl(sUrl: string): RawByteString;
    procedure IqReplyError(sId, xmlns: string; nErrCode: Integer);
    procedure ProcessAliases(var sLogin, sKey: string);
    procedure ProcessGetRoster(const sId: string);
    function ProcessGetVCard(sId: string; Node: TjanXMLNode2): Boolean;
    procedure ProcessIq(Node: TjanXMLNode2);
    procedure ProcessIqGetDefault(Node: TjanXMLNode2);
    procedure ProcessJabStream;
    procedure ProcessOnline(XML: TjanXMLParser2);
    procedure ProcessResult(Node: TjanXMLNode2);
    procedure QueryClientVersion(bForce: Boolean; sId: string = '');
    procedure SetAliveTested(const Value: Boolean);
    procedure SetPresShow(Value: string);
    function ToXmlRosterItem(fr: TFriend): string;
    procedure XmlSendVCard(sId, sAddr: string; fr: TFriend);
  public
    Context: TIdContext;
    dtPresShow: TDateTime;
    OnLog: procedure (const str: string) of object;
    OnMessage: procedure(msg:TGateMessage) of object;
    OnCheckPass: function(sKey: string):boolean of object;
    OnAuthorized: procedure(sLogin: string) of object;
    OnGetFriend: function(sAddr:string):TFriend of object;
    OnIdle: procedure of object;
    OnStillAlive: TObjProc;
    Profile: TGateStorage;
    sJid: string;
    sKey: string;
    sLogin: string;
    sServerName: string;
    Status: TJsStatus;
    UserStatus: TJsUserStatus;
    Terminate: Boolean;
    constructor Create(AContext: TIdContext);
    destructor Destroy; override;
    procedure AliveTest;
    function UrlExtractFileName(const FileName: string): string; overload;
    function FriendsDiff(was, became: TFriendList): TFriendList;
    function XmlGetAttr(Node: TjanXMLNode2; const Child, Attr: string): string;
    function InputQuery(const Captioin, Prompt: string; var sVal: string): Boolean;
    procedure InternalOnExecute;
    procedure Log(const Value: string);
    procedure OnDisconnected(Sender: TObject);
    function Packet_SendMessage(msg: TGateMessage): UTF8String;
    procedure ProcessMessage(Node: TjanXMLNode2);
    function Recv(iLogNum: Integer): string; overload;
    function Recv: string; overload;
    procedure SaveFriends(friends: TFriendList);
    procedure Send(str: string; iLogNum: Integer); overload;
    procedure Send(const str: string); overload;
    procedure SendFmt(const str: string; args: array of const);
    procedure SendingUnavailable(msg: TGateMessage);
    procedure SendMessage(msg: TGateMessage); overload;
    procedure SendMessage(sFrom, sBody: string; bSendLast: boolean = false);
        overload;
    procedure SendMsgQueue;
    procedure StartTls(AContext: TIdContext);
    function UTF8BytesToString(bytes: TIdBytes): string;
    class function StringToUTF8Bytes(str: string): TIdBytes;
    function ToXmlPresence(fr: TFriend): string;
    procedure Typing(sFrom, sEvent: string);
    procedure UpdatePresences(friends: TFriendList);
    procedure WriteFileTest(str: RawByteString);
    property OnPresShowChanged: TObjProc read FOnPresShowChanged write
        FOnPresShowChanged;
    property AliveTested: Boolean read FAliveTested write SetAliveTested;
    property PresShow: string read FPresShow write SetPresShow;
  end;

implementation

uses
  Vcl.Dialogs, System.SysUtils, System.UITypes, System.StrUtils, ufrmMemoEdit,
  IdSSL, System.Variants, uvsDebug, synacode, System.DateUtils;



constructor TJabberServerSession.Create(AContext: TIdContext);
begin
  inherited Create(nil);

  UserStatus:=just_online;

  Context:=AContext;
  Context.Data:=Self;
  Context.Connection.OnDisconnected:=OnDisconnected;

  MsgQueue:=TObjectList<TGateMessage>.Create(true);

  //sServerName:='localhost';
  sServerName:='vkxmpp.hopto.org';

  StFriendsGlobal := TGateStorage.Create(Self);
  StFriendsGlobal.Path := AbsPath('friendsGlobal');
end;

destructor TJabberServerSession.Destroy;
begin

  if Assigned(FLastFriends) then
    FLastFriends.Free;

  //SOLVED: if this line uncommented - IndyTCPServer.Contexts.Count does not decrements
  // AV ?
  inherited;
end;

procedure TJabberServerSession.AliveTest;
var
  sSysJid: string;
begin
  sSysJid:='sys@'+sServerName;

  if (AliveTestMethod='') or (AliveTestMethod='at_version') then
  begin
    QueryClientVersion(true, 'at_version');
  end;
  if (AliveTestMethod='') or (AliveTestMethod='at_ping') then
  begin
    SendFmt(
    '<iq from="%s" to="%s" id="at_ping" type="get">'+
    '<ping xmlns="urn:xmpp:ping"/>'+
    '</iq>',
      [sSysJid, sJid]);
  end;
  if (AliveTestMethod='') or (AliveTestMethod='at_probe') then
  begin
    SendFmt(
      '<presence id="at_probe" type="probe" from="%s" to="%s"/>'
      , [sSysJid, sJid]
    );
  end;

  if AliveTestMethod='' then
    AliveTestMethod:='none'; //until no results of tests

end;

function TJabberServerSession.DecodeBase64(const CinLine: D7String): D7String;
const
  RESULT_ERROR = -2;
var
  inLineIndex: Integer;
  c: D7Char;
  x: SmallInt;
  c4: Word;
  StoredC4: array[0..3] of SmallInt;
  InLineLength: Integer;
begin
  Result := '';
  inLineIndex := 1;
  c4 := 0;
  InLineLength := Length(CinLine);

  while inLineIndex <= InLineLength do
  begin
    while (inLineIndex <= InLineLength) and (c4 < 4) do
    begin
      c := CinLine[inLineIndex];
      case c of
        '+'     : x := 62;
        '/'     : x := 63;
        '0'..'9': x := Ord(c) - (Ord('0')-52);
        '='     : x := -1;
        'A'..'Z': x := Ord(c) - Ord('A');
        'a'..'z': x := Ord(c) - (Ord('a')-26);
      else
        x := RESULT_ERROR;
      end;
      if x <> RESULT_ERROR then
      begin
        StoredC4[c4] := x;
        Inc(c4);
      end;
      Inc(inLineIndex);
    end;

    if c4 = 4 then
    begin
      c4 := 0;
      Result := Result + D7Char((StoredC4[0] shl 2) or (StoredC4[1] shr 4));
      if StoredC4[2] = -1 then Exit;
      Result := Result + D7Char((StoredC4[1] shl 4) or (StoredC4[2] shr 2));
      if StoredC4[3] = -1 then Exit;
      Result := Result + D7Char((StoredC4[2] shl 6) or (StoredC4[3]));
    end;
  end;
end;

procedure TJabberServerSession.ProcessAuth(xml: TjanXMLNode2);
begin

  sKey:=xml.getChildByName('auth').text;
  sLogin:=DecodeBase64(sKey);

  if (Length(sLogin)>0) and (sLogin[1]=Char(0)) then  //Psi - style
    sLogin:=copy(sLogin, 2, 99999);

  sLogin:=PChar(sLogin);

  ProcessAliases(sLogin, sKey);

  if OnCheckPass(sKey) then
  begin
    Send('<success xmlns=''urn:ietf:params:xml:ns:xmpp-sasl''/>');
    Status:=jsst_authdone;
  end;
  //TODO
  //else DISCONNECT

end;

procedure TJabberServerSession.DoSasl(AContext: TIdContext);
const
S1 =
'<?xml version=''1.0''?>'+
'<stream:stream xmlns=''jabber:client'''+
'xmlns:stream=''http://etherx.jabber.org/streams'' '+
'id=''c2s_201898'' from=''%s'' version=''1.0''>'+
'<stream:features>'#13#10+
    '<mechanisms xmlns=''urn:ietf:params:xml:ns:xmpp-sasl''>'#13#10+
      //'<mechanism>DIGEST-MD5</mechanism>'#13#10+
      '<mechanism>PLAIN</mechanism>'#13#10+
    '</mechanisms>'#13#10+
  '</stream:features>';
begin

  Recv;
  SendFmt(S1, [sServerName]);
  Status:=jsst_auth;

end;

procedure TJabberServerSession.DoTls(AContext: TIdContext);
begin
       Send(
      '<stream:features><starttls xmlns=''urn:ietf:params:xml:ns:xmpp-tls''/>'#13#10+
  '<compression xmlns=''http://jabber.org/features/compress''>'#13#10+
     '<method>zlib</method>'#13#10+
  '</compression>'#13#10+
  '<mechanisms xmlns=''urn:ietf:params:xml:ns:xmpp-sasl''>'#13#10+
  // '<mechanism>DIGEST-MD5</mechanism>'#13#10+
   '<mechanism>PLAIN</mechanism></mechanisms>'#13#10+
   '<register xmlns=''http://jabber.org/features/iq-register''/>'#13#10+
  '</stream:features>'
      );

          Recv;

        Send(
        '<proceed xmlns=''urn:ietf:params:xml:ns:xmpp-tls''/>'
        );

  StartTls(Context);
end;

function TJabberServerSession.UrlExtractFileName(const FileName: string):
    string;
var
  I: Integer;
begin
  I := FileName.LastDelimiter('\/' + DriveDelim);
  Result := FileName.SubString(I + 1);
end;

function TJabberServerSession.FriendsDiff(was, became: TFriendList):
    TFriendList;
var
  diff: TFriendList;
  I: Integer;
  j: Integer;
begin
  diff:=TFriendList.Create(true);


  for I := 0 to became.Count-1 do
  begin
    if Assigned(was) then
    begin
      j:=FriendFind(was, became[i].sAddr);
      if j>-1 then
      begin
        if was.Items[j].Presence=became[i].Presence then
          continue;
      end;
    end;

    diff.Add(became[i].Duplicate);
  end;


  Result := diff;
end;

function TJabberServerSession.XmlGetAttr(Node: TjanXMLNode2; const Child, Attr:
    string): string;
begin
  Result := '';

  if Child='' then
  begin
    Result:=Node.attribute[Attr];
    exit;
  end;

  if Node.getChildByName(Child)<>nil then
        Result:=Node.getChildByName(Child).attribute[Attr];

end;

function TJabberServerSession.GetBase64DataByUrl(sUrl: string): RawByteString;
var
  ss: TStringStream;
  sImgB64: string;
begin

  Result := '';

  try
    Result := HttpMethodRawByte(sUrl, false);
    Result := EncodeBase64(Result);
  except
  end;

      {     // DBG
  sl:=TStringList.Create;
  //sl.LoadFromFile('v:\_inbox\imgb64.txt');
  //sImgB64:=sl.Text;
  sl.Text := sImgB64;
  sl.SaveToFile('v:\_inbox\img_.jpg');
  sl.Free;
           };
end;

function TJabberServerSession.GetUserPhotoSha1Hex(sJid, sPhotoUrl: string):
    string;
var
  rbImgData: RawByteString;
  sl: TStringList;
  sShaValName: string;
begin
  Result :='';

  sl:=TStringList.Create;

  sShaValName:=sJid+'_avatar';

  try
    sl.Text:=StFriendsGlobal.LoadValue(sShaValName);

    if sl.Count>1 then
    begin
      if UrlExtractFileName(sl.Strings[0])=UrlExtractFileName(sPhotoUrl) then
      begin
        Result:=sl.Strings[1];
        exit;
      end;
    end;



    try
      rbImgData:=HttpMethodRawByte(sPhotoUrl, false);
    except
    end;

    if rbImgData<>'' then
     begin
       Result := Sha1Hex(rbImgData);
       sl.Clear;
       sl.Add(sPhotoUrl);
       sl.Add(Result);
       StFriendsGlobal.SaveValue(sShaValName, sl.Text);
     end;
  finally
    sl.Free;
  end;
end;

function TJabberServerSession.InputQuery(const Captioin, Prompt: string; var
    sVal: string): Boolean;
begin
Result:=false;

  frmMemoEdit.Caption:=IntToHex(Integer(Self), 8) ;

  frmMemoEdit.Memo.Text:=sVal;

  if frmMemoEdit.Visible then
    exit;

  frmMemoEdit.ShowModal;

  sVal := frmMemoEdit.Memo.Text;
  Result := frmMemoEdit.ModalResult=mrOk;

  end;

procedure TJabberServerSession.InternalOnExecute;
var
  s: string;
  s2: string;
  XML: TjanXMLParser2;
begin

try
  //OnLog('enter');

  if Status=jsst_online then
    SendMsgQueue;

try
  if Status=jsst_connecting then
  begin
    OnLog('TCP connected IP: '+Self.Context.Binding.PeerIP+
      ' Con.Count='+IntToStr(ClientCount));
    DoSasl(Context);
    exit;
  end;

  XML:=TjanXmlParser2.Create;

  try
    s:=Recv;

    if(Pos('<BINVAL>', s)<>0)then
      if(Pos('Trillian', sClientProgName)=0)then
        exit; //TODO: test BINVAL including to <STREAM> on others

      // BINVAL - not supported
      // When tested:
      // BINVAL can be splited into several sendings
      // must be merging (not realized)

    if Pos('<?xml', LowerCase(s))<>1  then
      s2:=Format('<STREAM>%s</STREAM>', [s]);
    try
      xml.xml:=UnicodeToAnsiEscape(s2);
    except
      try
        xml.xml:=UnicodeToAnsiEscape(s+'</stream:stream>');
      except
        s:=ReplaceStr(s2, '</stream:stream>', '');
        xml.xml:=UnicodeToAnsiEscape(s);
      end;
    end;
  except
  end;

   if (xml.FirstChild<>nil) and (LowerCase(xml.FirstChild.name)='auth') then
  begin
    ProcessAuth(xml);
    exit;
  end;

  if Status<jsst_authdone then
    exit;


  ProcessOnline(XML);

finally
  //OnLog('exit');
  xml.Free;
end;

except on e:Exception do
  begin
    Log('Internal error: '+e.Message);

    if Status>=jsst_authdone then
      SendMessage('xmppgate', 'Internal error: '+e.Message);
  end
    else
    begin
      Log('Unknown internal error');

      if Status>=jsst_authdone then
        SendMessage('xmppgate', 'Unknown internal error');
    end;
end;

end;

procedure TJabberServerSession.IqReplyError(sId, xmlns: string; nErrCode:
    Integer);
var
  sErrTag: string;
begin
  if nErrCode=503 then
    sErrTag:='<service-unavailable xmlns="urn:ietf:params:xml:ns:xmpp-stanzas" />'
  else
    sErrTag:='<feature-not-implemented xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>';

  SendFmt(
  '<iq from="%s" type="error" xml:lang="ru" to="%s" id="%s">'+CR+
  '<query xmlns="%s"/>'+
  '<error type="cancel" code="%d">'+CR+
  '%s'+CR+
  '</error>'+CR+
  '</iq>',
    [sServerName, sJid, sId, xmlns, nErrCode, sErrTag]);
end;

function TJabberServerSession.Recv(iLogNum: Integer): string;
var
  buf: TIdBytes;
begin

  SetLength(buf, 0);
  while length(buf)<1 do
    begin
      //Sleep(1000);
      Context.Connection.Socket.ReadTimeout:=1000;
      Context.Connection.Socket.ReadBytes(buf, -1, false);

      if (bTerminate or Terminate)  then
      begin
        if Context.Connection.Connected then
          Context.Connection.Disconnect;
        raise Exception.Create('TJabberServerSession terminated');
      end;


      if Assigned(OnIdle) then
        OnIdle;
    end;

  Result := UTF8BytesToString(buf);

  if bXmppLog then
  begin
    Log('RECV '+IfThen(DBGbServer, 'SERV', 'CLIENT')+IntToStr(iLogNum));
    Log(Result);
  end;
end;

procedure TJabberServerSession.Send(str: string; iLogNum: Integer);
var
  buf: TIdBytes;
begin

  buf:=StringToUTF8Bytes(str);
  Context.Connection.Socket.Write(buf);

  if bXmppLog then
  begin
    Log('SEND '+IfThen(DBGbServer, 'SERV', 'CLIENT')+IntToStr(iLogNum));
    Log(str);
  end;
end;

procedure TJabberServerSession.Log(const Value: string);
begin
  if(Assigned(OnLog))then
    OnLog(Value);
end;

procedure TJabberServerSession.OnDisconnected(Sender: TObject);
begin
  // TODO -cMM: TJabberServerSession.OnDisconnected default body inserted
end;

function TJabberServerSession.Packet_SendMessage(msg: TGateMessage): UTF8String;
var
  sDelay: string;
begin

  sDelay:='';

  // QIP 2012 annoying notifies about delayed(offline) messages
  // Pidgin BUG: all delayed messages interpreted as sent at 03:00:00
  if  (not IsOnlineMessageTime(msg.dt))
//      or ( (msg.dt<>0) and (Pos('QIP', sClientProgName)=0) )
      //I don't know but may be every message-offline
      // looks ugly in some other rare clients
      then
       sDelay:='<delay xmlns="urn:xmpp:delay"'+CR+
           //'from="capulet.com"'+CR+
           //'stamp="2002-09-10T23:08:25Z">'+CR+
           Format('stamp="%sT%sZ">'+CR+'</delay>', [
            FormatDateTime('yyyy-mm-dd', msg.dt),
            FormatDateTime('hh:mm:ss', msg.dt)]
            );
           //'Offline Storage'+CR+


 Result := Format(
           '<message type="chat" to="%S" from="%S" id="%s"><body>%S</body>%s</message>',
           [msg.sTo, msg.sFrom, msg.sId, XmlEscape(msg.sBody, true), sDelay]);
end;

procedure TJabberServerSession.ProcessAliases(var sLogin, sKey: string);
begin //TODO: Extract to domain_aliases config
  sLogin:=StringReplace(sLogin,
    '@vkxmpp2.hopto.org', '@vkxmpp.hopto.org', [rfIgnoreCase, rfReplaceAll]);
  sKey:=StringReplace(sKey,
    '@vkxmpp2.hopto.org', '@vkxmpp.hopto.org', [rfIgnoreCase, rfReplaceAll]);
end;

function TJabberServerSession.ProcessGetAvatar(sId, sTo: string): Boolean;
var
  fr: TFriend;
  sXml: string;
begin
  Result:=false;

  sXml:=
    '<iq id="%s" type="result" from="%s" to="%s">'+
    '<query xmlns="jabber:iq:avatar">'+
      '<data mimetype="image/jpeg">'+
        '%s'+
      '</data>'+
    '</query>'+
  '</iq>';

  if not Assigned(OnGetFriend) then
    exit;

  fr:=OnGetFriend(sTo);

  if not Assigned(fr) then
    exit;

  sXml:=Format(sXml, [sId, sTo, sJid, GetBase64DataByUrl(fr.vCard.sPhotoUrl)]);
  Send(sXml);

  Result:=true;
end;

procedure TJabberServerSession.ProcessGetRoster(const sId: string);
var
  sFriendItems: string;
begin
  Status:=jsst_online;
  AliveTest;
  SendMsgQueue;

  if Assigned(profile) then
    sFriendItems:=profile.LoadValue('friends');

  //if isDbg then
    //sJid:='vsevqip@vkxmpp.hopto.org/QIP';

  SendFmt(
    '<iq type="result" to="%s" id="%s">'#13#10+
    '<query xmlns="jabber:iq:roster">'#13#10+
    '<item subscription="both" name="%s" jid="support@%s"> <group>VkXmppGate</group> </item>'+CR+
    '<item subscription="both" name="____XmppGate-Bot" jid="%s"> <group>VkXmppGate</group> </item>'+CR+ // ����� �� ���������� ����-���� �����
    '%s'+CR+
    '</query>'+CR+
    '</iq>', [sJid, sId, SUPPORTNAME, sServerName, 'xmppgate@vkxmpp.hopto.org', sFriendItems]
    );                     //TODO: ���������� � ToXmlPresence, SaveFriends
                            //TODO: ���������� SaveFriends, ����������� callback GetFriends
                            //TODO: analyze redundancy with AddStdContacts
                            // describe here if it useful for first connection
                            // + if it added only here - the status is offline

  if not bAuth then   //TODO: ��������� � ���. ����������, � ���.�������: bAuth=Status=auth_done
  begin
    bAuth:=true;
    OnAuthorized(sLogin);
    //QueryClientVersion;
  end;
end;

function TJabberServerSession.ProcessGetVCard(sId: string; Node: TjanXMLNode2):
    Boolean;
var
  fr: TFriend;
  sAddr: string;
begin
  Result:=false;

  if not VarIsNull(Node.attribute['to']) then
    sAddr:=Node.attribute['to']
    else
      exit;

  if Assigned(OnGetFriend) then
    fr:=OnGetFriend(sAddr);

  if Assigned(fr) then
    XmlSendVCard(sId, sAddr, fr);

  Result:=true;
end;

procedure TJabberServerSession.ProcessIq(Node: TjanXMLNode2);
var
  sId: string;
  sTo: string;
begin

  if (LowerCase(Node.attribute['type'])='result')then
    ProcessResult(Node);

  if (sClientProgName='') and (Status<>jsst_online)then
    QueryClientVersion(true);
  //  ����� �������� ������ ����� Session //PSI
  //  ��������� ������� �����
  // ������ �������� ����� �������,
  // ����� � ������� ������� ������� � ��� ���� ������ �������

  if (Node.childCount>0) then
  begin
    if(LowerCase(Node.childNode[0].name)='bind') then
    begin
      sBindId:=Node.attribute['id'];

      //sJid:='vsevols@localhost/������������-��';
      if Node.getChildByName('bind').getChildByName('resource')<>nil then
        sJid:='me@'+sServerName+'/'+Node.getChildByName('bind').getChildByName('resource').text
        else
          sJid:='me@'+sServerName; //Pidgin sometimes doesn't send resource

      //TODO: Retrieve from login

      SendFmt(
      '<iq xmlns="jabber:client" type="result" id="%s">'#13#10+
      '<bind xmlns="urn:ietf:params:xml:ns:xmpp-bind">'#13#10+
      '<jid>%s</jid>'#13#10+
      '</bind>'#13#10+
      '</iq>' , [sBindId, sJid]
      );
    end;

    if LowerCase(Node.childNode[0].name)='session' then
    begin
      sId:=Node.attribute['id'];
      SendFmt(
      '<iq from="%s" type="result" id="%s"/>', [sServerName, sId]
      );

    end;
  end;


  if LowerCase(Node.attribute['type'])='get' then
  begin

    sId:=Node.attribute['id'];

    if Node.childCount>0 then
    if LowerCase(Node.childNode[0].attribute['xmlns'])='jabber:iq:roster' then
    begin
      ProcessGetRoster(sId);
      exit;
    end;


      if Node.getChildByName('vCard')<>nil then
      begin
        //if sClientProgName='Psi' then
        //  exit;
        // Otherway Psi forces user to fill out his VCard
        //TODO: test Psi

        if ProcessGetVCard(sId, Node) then
          exit;
      end;

      if Node.childCount>0 then
      if LowerCase(Node.childNode[0].attribute['xmlns'])='jabber:iq:avatar' then
      begin
        sTo:=Node.attribute['to'];
        if ProcessGetAvatar(sId, sTo) then
          exit;
      end;

      ProcessIqGetDefault(Node);
  end;

end;

procedure TJabberServerSession.ProcessIqGetDefault(Node: TjanXMLNode2);
var
  sId: string;
  xmlns: string;
begin

  //Pidgin needs nessesarily responses for IQs

  if true then
   begin
     try
       sId:=Node.attribute['id'];
       if Node.getChildByName('query')<>nil then
        xmlns:=Node.getChildByName('query').attribute['xmlns'];
     except
     end;

   if Node.childCount>0 then
   if Pos(Node.childNode[0].attribute['xmlns'], 'disco#info')>0 then
    begin
      SendFmt(
        '<iq from="%s"'+CR+
        'id="%s"'+CR+
        'to="%s"'+CR+
        'type="result">'+CR+
        '<query xmlns="http://jabber.org/protocol/disco#info">'+CR+
        '<feature var="http://jabber.org/protocol/chatstates"/>'+CR+
        '</query>'+CR+
        '</iq>', [XmlGetAttr(Node, '', 'to'), XmlGetAttr(Node, '', 'id'), XmlGetAttr(Node, '', 'from')]
      );
      exit;
    end;



     IqReplyError(sId, xmlns, 501);
   end;
end;

procedure TJabberServerSession.ProcessJabStream;
var
  s: string;
  sId: string;
begin
  sId:='c2s_201898';
  s:='<stream:stream xmlns="jabber:client" xmlns:stream="http://etherx.jabber.org/streams"'+
  ' id="%s" from="%s" version="1.0">'+
  '<stream:features><bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"/>'+
  '<session xmlns="urn:ietf:params:xml:ns:xmpp-session"/></stream:features>';
  SendFmt(s, [sId, sServerName]);
end;

procedure TJabberServerSession.ProcessMessage(Node: TjanXMLNode2);
var
  msg: TGateMessage;
begin
  // message event
  if Node.getChildByName('body')=nil then
    exit;

  msg:=TGateMessage.Create;
  msg.sTo:=LowerCase(VarToStr(Node.attribute['to']));
  msg.sFrom:=LowerCase(VarToStr(Node.attribute['from']));
  msg.sBody:=XmlEscape(Node.getChildByName('body').text, false);

  OnMessage(msg);
end;

procedure TJabberServerSession.ProcessOnline(XML: TjanXMLParser2);
var
  Node : TjanXMLNode2;
begin

if not assigned(XML.rootNode) then
exit;

  Node := XML.rootNode.FirstChild;

  if not Assigned(Node) then
    Node:=XML.rootNode;

  repeat
    if LowerCase(Node.name)='stream:stream' then
      ProcessJabStream;

    if LowerCase(Node.name)='iq' then
      ProcessIq(Node);

    if LowerCase(Node.name)='message' then
      ProcessMessage(Node);

    if (LowerCase(Node.name)='presence')then
    begin
      if Node.getChildByName('show')<>nil then
      begin
        PresShow:=Node.getChildByName('show').text;
      end
        else
          PresShow:='';

      if (node.attribute['type']='') then
      begin
        //
      end;
    end;

    Node := Node.NextSibling;
  until not Assigned(Node) ;
end;

procedure TJabberServerSession.ProcessResult(Node: TjanXMLNode2);
begin

  try
    if Node.attribute['id']='ask_version' then
    begin
      if sClientProgName<>'' then
        exit;

      if (Node.getChildByName('query')<>nil) then
       begin
         if (Node.getChildByName('query').getChildByName('name')<>nil) then
            sClientProgName:=Node.getChildByName('query').getChildByName('name').text;

        if (Node.getChildByName('query').getChildByName('version')<>nil) then
            sClientVersion:=Node.getChildByName('query').getChildByName('version').text;

        if (Node.getChildByName('query').getChildByName('os')<>nil) then
            sClientOs:=Node.getChildByName('query').getChildByName('os').text;


        OnLog(Format('%s CLIENT: %s VER: %s OS: %s',
          [sKey, sClientProgName, sClientVersion, sClientOs]));

       end;
    end;

    if Pos('at_',Node.attribute['id'])=1 then
    begin
      AliveTested:=True;
      if AliveTestMethod='' then
      begin
        AliveTestMethod:=Node.attribute['id'];
        OnLog(Format('AT_ result: %s (selected as AliveTestMethod)', [Node.attribute['id']]));
      end
        else OnLog(Format('AT_ result: %s', [Node.attribute['id']]));
    end;

  except
  end;
end;

procedure TJabberServerSession.QueryClientVersion(bForce: Boolean; sId: string
    = '');
var
  sXml: string;
begin
  if QueryClientVersionDone and not bForce then
    exit;

  if sId='' then
    sId:='ask_version';

  sXml:=
  '<iq from="%s" type="get" to="%s" id="%s">'+CR+
  '<query xmlns="jabber:iq:version"/>'+CR+
  '</iq>';

  Send(Format(sXml, ['sys@'+sServerName, sJid, sId]));

  if Status=jsst_online then
    QueryClientVersionDone:=true;

end;

function TJabberServerSession.Recv: string;
begin
  Result:=Recv(GetCurrentThreadId);
end;

procedure TJabberServerSession.SaveFriends(friends: TFriendList);
var
  i: Integer;
  sData: string;
  sXml: string;
begin

  sXml:=CR+
  '<item subscription="both" name="%s" jid="%s">'+CR+
  '<group>%s</group>'+CR+
  '</item>'+CR;

  sData:='';
  for i := 0 to friends.Count-1 do
  begin

    sData:=sData+Format(sXml, [XmlEscape(friends[i].sFullName, true), friends[i].sAddr, XmlEscape(friends[i].sGroup, true)]);
  end;


  Profile.SaveValue('friends', sData);

end;

procedure TJabberServerSession.Send(const str: string);
begin
  Send(str, GetCurrentThreadId);
end;

procedure TJabberServerSession.SendFmt(const str: string; args: array of const);
begin
  Send(Format(str, args));
end;

procedure TJabberServerSession.SendingUnavailable(msg: TGateMessage);
var
  sXml: string;
begin                         //TODO: ���������� ���������
  sXml:=
  '<message from="%s" type="error" to="%s" id="%s">'+
  '<subject/>'+
  '<body>%s</body>'+
  //'<nick xmlns="http://jabber.org/protocol/nick">%s</nick>' +
  '<error type="cancel" code="503">' +
  '<service-unavailable xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>' +
  '</error>'+
  '</message>';

  sXml:=Format(sXml, [msg.sTo, msg.sFrom, msg.sId, XmlEscape(msg.sBody, true)]);

  Send(sXml);

end;

procedure TJabberServerSession.SendMessage(msg: TGateMessage);
begin
  if Status=jsst_online then
  begin
    if msg.sType='typing' then
    begin
      if msg.sBody<>'paused' then
        Typing(msg.sFrom, 'composing')
        else
          Typing(msg.sFrom, 'paused');
      exit;
    end;

    Send(Packet_SendMessage(msg))
  end
    else
      MsgQueue.Add(msg.Duplicate);
      //TODO: may be recursively SendMessage->MsgQueue.Add->SendMessage is
      // the reason of duplicating
end;

procedure TJabberServerSession.SendMessage(sFrom, sBody: string; bSendLast:
    boolean = false);
var
  msg: TGateMessage;
begin
  msg:=TGateMessage.Create;
  msg.sFrom:=sFrom;
  msg.sBody:=sBody;
  msg.sTo:=sJid;

  if not bSendLast then
    SendMessage(msg)
    else
      MsgQueue.Add(msg.Duplicate);

  msg.Free;
end;

procedure TJabberServerSession.SendMsgQueue;
var
  I: Integer;
begin
  for I := 0 to MsgQueue.Count-1 do
    SendMessage(MsgQueue[i]);

  MsgQueue.Clear;
end;

procedure TJabberServerSession.SetAliveTested(const Value: Boolean);
begin
  if FAliveTested = Value then
    exit;

  FAliveTested := Value;

  if not Value then
    if AliveTestMethod<>'none' then
      AliveTest
      else
        FAliveTested:=True;

  if FAliveTested then
    OnStillAlive;
end;

procedure TJabberServerSession.SetPresShow(Value: string);
begin
  Value:=LowerCase(Trim(Value));

  if FPresShow = Value then
    exit;

  FPresShow := Value;
  dtPresShow:=IncHour(TTimeZone.Local.ToUniversalTime(Now), 4);
  OnPresShowChanged();

end;

function TJabberServerSession.Sha1Hex(rb: RawByteString): string;
begin
  Result := ToHex(Sha1(rb));
end;

procedure TJabberServerSession.StartTls(AContext: TIdContext);
begin

  if (AContext.Connection.IOHandler is TIdSSLIOHandlerSocketBase) then begin
      (AContext.Connection.IOHandler as TIdSSLIOHandlerSocketBase).PassThrough := False;
  end;
end;

function TJabberServerSession.UTF8BytesToString(bytes: TIdBytes): string;
begin
    SetLength(bytes, Length(bytes)+1);
    bytes[Length(bytes)-1]:=Byte(0);

    Result := UTF8ToString(PAnsiChar(bytes));
end;

class function TJabberServerSession.StringToUTF8Bytes(str: string): TIdBytes;
var
  rs: RawByteString;
begin
    rs:=UTF8Encode(str);
    SetLength(Result, Length(rs));
    Move(rs[1], Result[0], Length(Result));
    //WriteFileTest(rs);
end;

function TJabberServerSession.ToHex(rb: RawByteString): string;
var
  i: Integer;
begin
  Result:='';

  for i := Low(rb) to High(rb) do
  begin
    Result:=Result+IntToHex(Ord(rb[i]), 2);
  end;
  Result:=LowerCase(Result);
end;

function TJabberServerSession.ToXmlPresence(fr: TFriend): string;
var
  bTrillian: boolean;
  sAvatar: string;
  sHash: string;
  sShow: string;
  sType: string;
  sXml: string;
begin

  sXml:='';
 {
  sXml:=
  '<presence'+CR+
    'from="%s"'+CR+
    'to="%s"%s>'+CR+
  '<show>%s</show>'+CR+
  //'<status>be right back</status>'+CR+
  //'<priority>0</priority>'+CR+
'</presence>' ;
   }

  sXml:=
    CR+'<presence'+
      ' from="%s"'+
      ' to="%s"%s>%s</presence>';
  //QIP hangs if there are CR in tag here!!!

  sShow:=IfThen(fr.Presence<>fp_offline, 'online', '');

  sType:=IfThen(fr.Presence<>fp_offline, '', ' type="unavailable"');

  sAvatar:='';

  bTrillian:=false;//Pos('Trillian', sClientVersion)<>0;

  if true then//not bTrillian then
  begin
    if fr.vCard.sPhotoUrl<>'' then
      sHash:=GetUserPhotoSha1Hex(fr.sAddr, fr.vCard.sPhotoUrl);
      sAvatar:=
        Format(
          '<x xmlns="jabber:x:avatar">'+
          '<hash>%s</hash>'+
          '</x>'+CR+
          '<x xmlns="vcard-temp:x:update">'+
          '<photo>%s</photo>'+
          '</x>'
          ,
          [sHash, sHash]);
  end
    else
    begin
      sXml:=
        CR+'<presence'+
          ' from="%s"'+
          ' to="%s"%s/>';
       //Trillian stops working in case of expanded PRESENCE (without specified type)
       // 13-1013 UPD: ??? Or it was incorrect notice
    end;


  //sXml:=Format(sXml, [fr.sAddr, sJid, sType, sShow]);
  Result:=Format(sXml, [fr.sAddr, sJid, sType, sAvatar]);


  //Result:=ReplaceStr(Result, CR, '');

end;

function TJabberServerSession.ToXmlRosterItem(fr: TFriend): string;
begin
  Result:=CR+'<item'+
        ' jid="%s"'+
      ' subscription="both"'+
      //'ask="subscribe"'+
      ' name="%s">'+
      '<group>%s</group>'+
  '</item>';

  Result:=Format(Result, [fr.sAddr, XmlEscape(fr.sFullName, true), XmlEscape(fr.sGroup, true)]);
end;

procedure TJabberServerSession.Typing(sFrom, sEvent: string);
begin
  {SendFmt(
    '<message'+CR+
    'from="%s"'+CR+
    'to="%s"'+CR+
    'type="chat">'+CR+
    '<active xmlns="http://jabber.org/protocol/chatstates"/>'+CR+
    '</message>',
      [sFrom, sJid]
    );
          }
  SendFmt(
    '<message'+CR+
    'from="%s"'+CR+
    'to="%s"'+CR+
    'type="chat">'+CR+
    '<%s xmlns="http://jabber.org/protocol/chatstates"/>'+CR+
    '</message>',
      [sFrom, sJid, sEvent]
    );
end;

procedure TJabberServerSession.UpdatePresences(friends: TFriendList);
var
  diff: TFriendList;
  I: Integer;
  sItems: string;
  sXml: string;
begin

  diff:=FriendsDiff(FLastFriends, friends);

  sXml:='';


    sItems:='';

      sXml:=
        '<iq type="set">'+CR+
        '<query xmlns="jabber:iq:roster">'+CR+
        '%s'+CR+
        '</query>'+CR+
      '</iq>'+CR;

    for I := 0 to diff.Count-1 do
      sItems:=sItems+ToXmlRosterItem(diff[i]);

    if Trim(sItems)<>'' then
      SendFmt(sXml, [sItems]);

    sXml:='';

    for I := 0 to diff.Count-1 do
      sXml:=sXml+ToXmlPresence(diff[i]);

    Send(sXml);


  diff.Free;

  if Assigned(FLastFriends) then
    FLastFriends.Free;

  FLastFriends:=FriendsCopy(friends);
end;

procedure TJabberServerSession.WriteFileTest(str: RawByteString);
var
  F: TextFile;
  S: String;
begin
  AssignFile(F, 'Test.txt', CP_UTF8);
  Rewrite(F);
  Write(F, str);
  CloseFile(F);
end;

procedure TJabberServerSession.XmlSendVCard(sId, sAddr: string; fr: TFriend);
var
   rbsImgB64: RawByteString;
   sFmt: string;
   sXml: string;
begin             //http://xmpp.org/extensions/xep-0054.html
    sXml:='';
    sFmt:=
  '<iq from="%s" to="%s" id="%s" type="result">'+
  '<vCard xmlns="vcard-temp">'+
  '<FN>%s</FN>'+
  //'<BDAY>1986-04-16</BDAY>'+
  '<ROLE />'+
  '<DESC></DESC>';
  sXml:=Format(sFmt, [sAddr, sJid, sId, fr.sFullName]);
  sFmt:=
  '<URL>%s</URL>'+
  '<TEL>'+
  '<NUMBER />'+
  '</TEL>'+
  '<PHOTO>'+
  '<TYPE>image/jpeg</TYPE>'+
  '<BINVAL>%s</BINVAL></PHOTO>'+
  '<EMAIL>'+
  '<USERID></USERID>'+
  '</EMAIL>'+
  '<ADR>'+
  '<STREET />'+
  '<LOCALITY></LOCALITY>'+
  '<REGION />'+
  '<PCODE />'+
  '<CTRY></CTRY>'+
  '</ADR>'+
  '<NICKNAME></NICKNAME>'+
  '</vCard>'+
  '</iq>';

  rbsImgB64:=GetBase64DataByUrl(fr.vCard.sPhotoUrl);
  sXml:=sXml+Format(sFmt, [fr.vCard.sUrl, rbsImgB64]);

  Send(sXml);
end;

end.



