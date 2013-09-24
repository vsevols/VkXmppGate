unit JabberServerSession;

// (C) Vsevols 18.09.2013
// http://vsevols.livejournal.com
// vsevols@gmail.com


interface

uses
  IdContext, IdTCPClient, System.Classes, IdGlobal, GateGlobals, janXMLparser2,
  windows, D7Compat, System.Generics.Collections;

type
  TJsStatus = (jsst_connecting, jsst_auth, jsst_authdone, jsst_online);
  TJabberServerSession = class;
  TJabberServerSession = class(TComponent)
  private
    bAuth: Boolean;
    DBGbServer: Boolean;
    bTls: Boolean;
    Context: TIdContext;
    FLastFriends: TFriendList;
    MsgQueue: TObjectList<TGateMessage>;
    sBindId: string;
    sClientOs: string;
    sClientProgName: string;
    sClientVersion: string;
    sJid: string;
    function DecodeBase64(const CinLine: D7String): D7String;
    procedure ProcessAuth(xml: TjanXMLNode2);
    procedure DoSasl(AContext: TIdContext);
    procedure DoTls(AContext: TIdContext);
    procedure IqReplyError(sId, xmlns: string; nErrCode: Integer);
    procedure ProcessGetRoster(const sId: string);
    procedure ProcessIq(Node: TjanXMLNode2);
    procedure ProcessIqGetDefault(Node: TjanXMLNode2);
    procedure ProcessJabStream;
    procedure ProcessOnline(XML: TjanXMLParser2);
    procedure ProcessResult(Node: TjanXMLNode2);
    procedure QueryClientVersion;
    function ToXmlRosterItem(fr: TFriend): string;
  public
    OnLog: procedure (const str: string) of object;
    OnMessage: procedure(msg:TGateMessage) of object;
    OnCheckPass: function(sKey: string):boolean of object;
    OnAuthorized: procedure(sLogin: string) of object;
    OnIdle: procedure of object;
    Profile: TGateStorage;
    sKey: string;
    sLogin: string;
    sServerName: string;
    Status: TJsStatus;
    constructor Create(AContext: TIdContext);
    destructor Destroy; override;
    function FriendsDiff(was, became: TFriendList): TFriendList;
    function InputQuery(const Captioin, Prompt: string; var sVal: string): Boolean;
    procedure InternalOnExecute;
    procedure Log(const Value: string);
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
    function ToXmlPresence_(fr: TFriend): string;
    procedure StartTls(AContext: TIdContext);
    function UTF8BytesToString(bytes: TIdBytes): string;
    function StringToUTF8Bytes(str: string): TIdBytes;
    function ToXmlPresence(fr: TFriend): string;
    procedure UpdatePresences(friends: TFriendList);
    procedure WriteFileTest(str: RawByteString);
  end;

implementation

uses
  Vcl.Dialogs, System.SysUtils, System.UITypes, System.StrUtils, ufrmMemoEdit,
  IdSSL, System.Variants, uvsDebug;



constructor TJabberServerSession.Create(AContext: TIdContext);
begin
  inherited Create(nil);
  Context:=AContext;
  AContext.Data:=Self;

  MsgQueue:=TObjectList<TGateMessage>.Create(true);

  //sServerName:='localhost';
  sServerName:='vkxmpp.hopto.org';

end;

destructor TJabberServerSession.Destroy;
begin
  inherited;

  if Assigned(FLastFriends) then
    FLastFriends.Free;
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
'id=''c2s_201898'' from=''localhost'' version=''1.0''>'+
'<stream:features>'#13#10+
    '<mechanisms xmlns=''urn:ietf:params:xml:ns:xmpp-sasl''>'#13#10+
      //'<mechanism>DIGEST-MD5</mechanism>'#13#10+
      '<mechanism>PLAIN</mechanism>'#13#10+
    '</mechanisms>'#13#10+
  '</stream:features>';
begin

  Recv;
  Send(S1);
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
  XML: TjanXMLParser2;
begin

try
  //OnLog('enter');

  if Status=jsst_online then
    SendMsgQueue;

try
  if Status=jsst_connecting then
  begin
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
      // must be merging (not realised)

    if Pos('<?xml', LowerCase(s))<>1  then
      xml.xml:=Format('<STREAM>%s</STREAM>', [s])
      else
      xml.xml:=s;
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
      SendMessage('xmppGate', 'Internal error: '+e.Message);
  end
    else
    begin
      Log('Unknown internal error');

      if Status>=jsst_authdone then
        SendMessage('xmppGate', 'Unknown internal error');
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

      if bTerminate then
        Context.Connection.Disconnect;

      if Assigned(OnIdle) then
        OnIdle;
    end;

  Result := UTF8BytesToString(buf);

  if isDbg then
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

  if isDbg then
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

function TJabberServerSession.Packet_SendMessage(msg: TGateMessage): UTF8String;
var
  sDelay: string;
begin

  sDelay:='';

  if msg.dt<>0 then
   sDelay:='<delay xmlns="urn:xmpp:delay"'+CR+
       //'from="capulet.com"'+CR+
       //'stamp="2002-09-10T23:08:25Z">'+CR+
       Format('stamp="%s">', [FormatDateTime('yyyy-mm-dd hh:mm:ss', msg.dt)])+CR+
       //'Offline Storage'+CR+
       '</delay>';


 Result := Format(
           '<message type="chat" to="%S" from="%S" id="%s"><body>%S</body>%s</message>',
           [msg.sTo, msg.sFrom, msg.sId, XmlEscape(msg.sBody, true), sDelay]);
end;

procedure TJabberServerSession.ProcessGetRoster(const sId: string);
var
  sFriendItems: string;
begin
  Status:=jsst_online;
  SendMsgQueue;

  if Assigned(profile) then
    sFriendItems:=profile.LoadValue('friends');

  //if isDbg then
    //sJid:='vsevqip@vkxmpp.hopto.org/QIP';

  SendFmt(
    '<iq type="result" to="%s" id="%s">'#13#10+
    '<query xmlns="jabber:iq:roster">'#13#10+
    '<item subscription="both" name="%s" jid="support@%s"/>'+CR+
    '<item subscription="both" name="xmppgate" jid="xmppgate"/>'+CR+ // чтобы не срабатывал анти-спам квипа
    '%s'+CR+
    '</query>'+CR+
    '</iq>', [sJid, sId, SUPPORTNAME, sServerName, sFriendItems]
    );                     //TODO: объединить с ToXmlPresence, SaveFriends
                            //TODO: упразднить SaveFriends, запрашивать callback GetFriends

  if not bAuth then   //TODO: перенести в лок. переменную, в нач.функции: bAuth=Status=auth_done
  begin
    bAuth:=true;
    OnAuthorized(sLogin);
    //QueryClientVersion;
  end;
end;

procedure TJabberServerSession.ProcessIq(Node: TjanXMLNode2);
var
  sFriendItems: string;
  sId: string;
begin

  if (LowerCase(Node.attribute['type'])='result')then
    ProcessResult(Node);

  if (sClientProgName='') and (Status<>jsst_online)then
    QueryClientVersion;
  //  ответ приходит только после Session //PSI
  //  проверено опытным путем
  // однако посылать стоит заранее,
  // чтобы к моменту запроса ростера у нас была версия клиента

  if (Node.childCount>0) then
  begin
    if(LowerCase(Node.childNode[0].name)='bind') then
    begin
      sBindId:=Node.attribute['id'];

      //sJid:='vsevols@localhost/пользователь-ПК';
      if Node.getChildByName('bind').getChildByName('resource')<>nil then
        sJid:='me@'+sServerName+'/'+Node.getChildByName('bind').getChildByName('resource').text
        else
          sJid:='me@'+sServerName; //Pidgin sometimes...

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
    if LowerCase(Node.childNode[0].attribute['xmlns'])='jabber:iq:roster' then
    begin
      sId:=Node.attribute['id'];
      ProcessGetRoster(sId);
      exit;
    end;

    if sClientProgName='Psi' then
      if Node.getChildByName('vCard')<>nil then
        exit;
      // Otherway Psi forces user to fill out his VCard

      //if sClientProgName<>'Trillian' then
        ProcessIqGetDefault(Node);
  end
  else
  begin
    if false then
    if sClientProgName='Trillian' then  // not tested for others
    if LowerCase(Node.attribute['type'])='set' then
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

  // if Pos(Node.childNode[0].attribute['xmlns'], 'disco#info')>0 then

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
  msg.sTo:=VarToStr(Node.attribute['to']);
  msg.sFrom:=VarToStr(Node.attribute['from']);
  msg.sBody:=XmlEscape(Node.getChildByName('body').text, false);
  OnMessage(msg);
end;

procedure TJabberServerSession.ProcessOnline(XML: TjanXMLParser2);
var
  Node : TjanXMLNode2;
begin
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
    if (node.attribute['type']='') then
    begin
      //
    end;

    Node := Node.NextSibling;
  until not Assigned(Node) ;
end;

procedure TJabberServerSession.ProcessResult(Node: TjanXMLNode2);
begin
  try
    if Node.attribute['id']='ask_version' then
    begin
      if (Node.getChildByName('query')<>nil) then
       begin
         if (Node.getChildByName('query').getChildByName('name')<>nil) then
            sClientProgName:=Node.getChildByName('query').getChildByName('name').text;

        if (Node.getChildByName('query').getChildByName('version')<>nil) then
            sClientVersion:=Node.getChildByName('query').getChildByName('version').text;

        if (Node.getChildByName('query').getChildByName('os')<>nil) then
            sClientOs:=Node.getChildByName('query').getChildByName('os').text;
       end;
    end;
  except
  end;
  OnLog(Format('%s CLIENT: %s VER: %s OS: %s',
    [sKey, sClientProgName, sClientVersion, sClientOs]));
end;

procedure TJabberServerSession.QueryClientVersion;
var
  sXml: string;
begin
  sXml:=
  '<iq from="%s" type="get" to="%s" id="ask_version">'+CR+
  '<query xmlns="jabber:iq:version"/>'+CR+
  '</iq>';

  Send(Format(sXml, [sServerName, sJid]));

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
begin                         //TODO: кешировать сообщения
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
    Send(Packet_SendMessage(msg))
    else
      MsgQueue.Add(msg.Duplicate);
end;

procedure TJabberServerSession.SendMessage(sFrom, sBody: string; bSendLast:
    boolean = false);
var
  msg: TGateMessage;
begin
  msg:=TGateMessage.Create;
  msg.sFrom:=sFrom;
  msg.sBody:=sBody;

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

function TJabberServerSession.ToXmlPresence_(fr: TFriend): string;
var
  sShow: string;
  sTo: string;
  sType: string;
  sXml: string;
begin             //TODO: восстановить на 0917 утро
  sXml:='';

  if Pos('QIP', sClientProgName)<>1 then
    sXml:=
      '<iq type="set">'+CR+
      '<query xmlns="jabber:iq:roster">'+CR+
        '<item'+CR+
            'jid="%s"'+CR+
            'subscription="both"'+CR+
            //'ask="subscribe"'+CR+
            'name="%s">'+CR+
          //'<group>MyBuddies</group>'+CR+
        '</item>'+CR+
      '</query>'+CR+
    '</iq>'+CR;


  Result:=Format(sXml, [fr.sAddr, XmlEscape(fr.sFullName, true)]);


  sShow:=IfThen(fr.Presence<>fp_offline, 'online', '');

  sType:=IfThen(fr.Presence<>fp_offline, '', ' type="unavailable"');


  sXml:=
  '<presence'+CR+
    'from="%s"'+CR+
    'to="%s"%s>'+CR+
  '<show>%s</show>'+CR+
  //'<status>be right back</status>'+CR+
  //'<priority>0</priority>'+CR+
'</presence>' ;
     //Trillian загибается от развёрнутого presence (при неуказанном type)

 {
  sXml:=
  '<presence'+CR+
    ' from="%s"'+CR+
    ' to="%s"%s'+CR+
   '/>'+CR;
  }


  sTo:=sJid;

  //if isDbg then
  //  sTo:='vsevqip@vkxmpp.hopto.org/QIP';

  Result:=Format(sXml, [fr.sAddr, sJid, sType, sShow]);
  //Result:=Result+Format(sXml, [fr.sAddr, sTo, sType]);


  Result:='<presence from="id3645474@vk.com/Adium" to="vsevqip@vkxmpp.hopto.org/QIP">'+
'<show>online</show>'+
//'<c xmlns="http://jabber.org/protocol/caps" node="http://pidgin.im/" hash="sha-1" ver="VUFD6HcFmUT2NxJkBGCiKlZnS3M=" />'+
//'<x xmlns="vcard-temp:x:update">'+
//'<photo>d27099820aefaabba7fe2e417c575ede7239ba02</photo>'+
//'</x>'+
'</presence>';

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

function TJabberServerSession.StringToUTF8Bytes(str: string): TIdBytes;
var
  rs: RawByteString;
begin
    rs:=UTF8Encode(str);
    SetLength(Result, Length(rs));
    Move(rs[1], Result[0], Length(Result));
    //WriteFileTest(rs);
end;

function TJabberServerSession.ToXmlPresence(fr: TFriend): string;
var
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
   }  //Trillian загибается от развёрнутого presence (при неуказанном type)


  sXml:=
    CR+'<presence'+
      ' from="%s"'+
      ' to="%s"%s/>';   //QIP hangs if there are CR in tag here!!!


  sShow:=IfThen(fr.Presence<>fp_offline, 'online', '');

  sType:=IfThen(fr.Presence<>fp_offline, '', ' type="unavailable"');

  //sXml:=Format(sXml, [fr.sAddr, sJid, sType, sShow]);
  Result:=Format(sXml, [fr.sAddr, sJid, sType]);


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

end.



