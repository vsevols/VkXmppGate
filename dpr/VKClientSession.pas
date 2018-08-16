unit VKClientSession;

// (C) Vsevols 2013
// http://vsevols.livejournal.com
// vsevols@gmail.com

interface

uses
  libeay32, OpenSSLUtils, System.Classes, IdTCPServer, System.Contnrs,
  janXMLparser2, GateGlobals, System.SysUtils, VkLongPollClient, XSuperObject,
  vkApi;

type
  //TVkSessionStatus = (vks_notoken, vks_ok, vks_captcha);


  TVxEmoji = class(TObject)
    function TranslateCode(sCode: string; var sTranslated: string): Boolean;
    function TranslateCodeHex(sCode: string; var sTranslated: string): Boolean;
  private
    FTable: TStringList;
    FTableName: string;
    FTablePath: string;
    function GetTranslationPair(I: Integer): TArray<string>;
  public
    constructor Create;
    destructor Destroy; override;
    function EncodeEmoticons(str: string): string;
    function SetTable(ATable: string): Boolean;
    function SetTablePath(const Value: string): Boolean;
    property TableName: string read FTableName;
    property TablePath: string read FTablePath;
  end;

  TVKClientSession = class(TComponent)
    function VkIdToJid(sSrc: string; bChatId: Boolean=false): string;
    function DumpNode(Node: TjanXMLNode2): string;
    function EmojiTranslate_(str: string; bFromVk: boolean): string;
    function EmojiTranslate(str: string; bFromVk: boolean): string;
    class function UnicodeToAnsiEscape1(str: string): AnsiString;
  private
    FApiToken: string;
    FIdLastMessage: Integer;
    FLongPollHasEvents: boolean;
    FOnCaptchaAccepted: TObjProc;
    FPersonsCache: TFriendList;
    FPrepareLastMessage: Integer;
    LongPoll: TVkLongPollClient;
    Msgs: TObjectList;
    sApiKey: string;
    sCaptchaResponse: string;
    function CheckNewMessages(AOutBox: Boolean): boolean;
    function DoVkApiCall(sUrl: string; slPost: TStringList = nil): TjanXMLParser2;
    function ExtractAuthCode(sCode: string): string;
    function GetAttachmentId(at: TjanXMLNode2): string;
    procedure InitLongPoll;
    function ParseMessageAttachments(Node: TjanXMLNode2; Msg: TGateMessage): string;
    function ProcessAttachedFwdMessages(fwdmessages: TjanXMLNode2; AMsg:
        TGateMessage): string;
    procedure SetApiToken(const Value: string);
    procedure SetLongPollHasEvents(const Value: boolean);
    procedure SetOnLog(const Value: TLogProc);
    procedure toMessage(Node: TjanXMLNode2);
    procedure toMessage3V(Node: TjanXMLNode2);
    function MessageBodyTranslate(sBody: string; bDirection, bEmoji: boolean):
        string;
    function QueryUserFullName(sUid: string): string;
    function VkApiCall(sUrl: string; slPost: TStringList = nil): TjanXMLParser2;
    property LongPollHasEvents: boolean read FLongPollHasEvents write
        SetLongPollHasEvents;
    //tcp: TIdTCPClient;
  public
    bSilentCaptchaFill: boolean;
    bSkipMarkedRead: boolean;
    Emoji: TVxEmoji;
    IsMobileClient: boolean;
    //Status: TVkSessionStatus;
    FOnLog: TLogProc;
    IgnoreChats: Boolean;
    Invisible: Boolean;
    MustProcessOutbox: Boolean;
    OnMessage: procedure(msg: TGateMessage) of object;
    OnCaptchaNeeded: procedure(sCaptchaSid: string; sCaptchaUrl:string; sUrl5:string) of object;
    // called with false when auth error occurs
    OnTokenNotify: procedure(bAuthorized: boolean) of object;
    sApiClientId: string;
    sCaptchaSid: string;
    sCaptchaUrl: string;
    sFullName: string;
    sSilCaptchaSid: string;
    sSilCaptchaUrl: string;
    Uid: string;
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;
    procedure ForwardMessage(msg: TGateMessage; AToAddr: string);
    procedure DoOnLog(const str: string);
    procedure DoOnTokenNotify(bAuthorized: Boolean);
    function QueryAccessToken(sCode: string): boolean;
    function GetCaptchaUrl5: string;
    function GetConfUserDescr(sUid: string): string;
    function GetFriends: TFriendList;
    function GetMsgWebLink(sChatUid, sMsgId: string): string;
    function GetMsgWebLinkByJid(AJid, AMsgId: string): string;
    function GetPerson(sAddr: string): TFriend;
    function GetPersons(sUids: string): TFriendList;
    function GetVkUrl: string;
    function IsReady: boolean;
    function JIdToVkUid(sTo: string): string;
    function JIdToChatId(sTo: string): string;
    procedure KeepStatus;
    function Max(a, b: Integer): Integer;
    procedure MsgMarkAsRead(const sId: string);
    function NodeGetChildText(Node: TjanXMLNode2; const sChild: string): string;
    procedure OnLongPollEvent;
    function ParseMessages(xml: TjanXMLParser2): boolean;
    procedure ProcessCaptchaNeeded(xml: TjanXMLNode2);
    function ProcessNewMessages: Boolean;
    procedure QueryUserInfo;
    procedure RespondCaptcha(str: string);
    function SendMessage_(msg: TGateMessage): Boolean;
    function SendMessage(msg: TGateMessage): Boolean;
    function VkDateToDateTime(sDate: string): TDateTime;
    procedure SetLastMessageId(ALast: Integer; bForce: boolean = false);
    procedure SetOffline;
    function SleepRandom(maxMilliseconds: Integer):integer;
    function TabifyFwdBody(sBody: string): string;
    procedure toFriend(Node: TjanXMLNode2; fl: TFriendList; sGroup: string = '');
    function VkApiCallFmt(const sMethod, sParams: string; args: array of const;
        slPost: TStringList = nil; AApiVersion: string = VKAPIVER3_0):
        TjanXMLParser2;
    function ApiCallJsonFmt(const AMethod, AParams: string; var AResponse:
        ISuperObject; args: array of const; AApiVersion: string = '3.0'): Boolean;
    procedure VkErrorCheck(xml: TjanXMLNode2);
    property ApiToken: string read FApiToken write SetApiToken;
    property IdLastMessage: Integer read FIdLastMessage;
    property OnCaptchaAccepted: TObjProc read FOnCaptchaAccepted write
        FOnCaptchaAccepted;
    property OnLog: TLogProc read FOnLog write SetOnLog;
  end;

procedure SleepEx(milliseconds: Cardinal;bAlertable: boolean);stdcall;
procedure SleepEx; external 'kernel32.dll' name 'SleepEx'; stdcall;

implementation

uses
  IdURI, IdSSLOpenSSL,
  IdHTTP, httpsend, Vcl.Dialogs, ssl_openssl, System.DateUtils, GateFakes,
  System.RegularExpressions, uvsDebug, System.StrUtils;



constructor TVKClientSession.Create(AOwner: TComponent);
var
  gs: TGateStorage;
  sl: TStringList;
begin
  inherited;


  gcs.Enter;
  Randomize;
  gcs.Leave;

  //tcp:=TIdTCPClient.Create(Self); //? Юзать ли ИНДИ
  gs:=TGateStorage.Create(Self);
  sl:=TStringList.Create;
  sl.Text:=gs.LoadValue('apiKeys');
  try
  if sl.Count<2 then
    raise Exception.Create('NO API KEYS!!');

    sApiClientId:=sl.Strings[0];
    sApiKey:=sl.Strings[1];
  finally
    sl.Free;
    gs.Free;
  end;

  (*TODO: extracted code
  LongPoll := TVkLongPollClient.Create(true);
  LongPoll.VkApiCallFmt:=VkApiCallFmt;
  LongPoll.OnEvent:=OnLongPollEvent;
  LongPoll.OnLog_:=OnLog_;
  *)
  InitLongPoll;


  Emoji := TVxEmoji.Create();
  Emoji.SetTablePath(AbsPath(Format('emos\%s.txt', ['VkEmojiGroup'])));
  FPersonsCache := TFriendList.Create();
  FPersonsCache.OwnsObjects:=True;
end;

destructor TVKClientSession.Destroy;
begin

  try
    if not Invisible then
      VkApiCallFmt('account.setOffline', '', []);
  except
  end;


  if Assigned(LongPoll) then
  begin
    if not LongPoll.Suspended then
    begin
      LongPoll.Terminate;
      LongPoll.WaitFor; //(?) hangs
      //while not LongPoll.Suspended do
        //SleepEx(1000, false);
    end;

    LongPoll.Free;
  end;

  FreeAndNil(Emoji);
  FreeAndNil(FPersonsCache);

  inherited;
end;

function TVKClientSession.QueryAccessToken(sCode: string): boolean;
var
  rx: TRegEx;
  sJson: string;
begin
  Result:=false;

  sCode:=ExtractAuthCode(sCode);
  try
    sJson:=HttpMethodSSL(   //NOT VkApiCall because reply is JSON
      Format(
      'https://api.vk.com/oauth/token?client_id=%s'+
      '&client_secret=%s&code=%s'+
      '&redirect_uri=https://oauth.vk.com/blank.html',
      [sApiClientId, sApiKey, sCode]));
  except on e:Exception do
    exit;
  end;

  ApiToken:=GetRxGroup(sJson, '"access_token":"(.+?)"', 1);
  //uid:=GetRxGroup(sJson, '"user_id":(\d+)', 1);
  QueryUserInfo();

  if ApiToken<>'' then
    Result:=true;

end;

function TVKClientSession.ExtractAuthCode(sCode: string): string;
var
  rx: TRegEx;
begin
  rx.Create('code=(.+)([=?&]|\z)');
  if rx.IsMatch(sCode) then
    Result:=rx.Match(sCode).Groups[1].Value
  else
    Result:=LowerCase(sCode);
end;

function TVKClientSession.CheckNewMessages(AOutBox: Boolean): boolean;
var
  LResponse: ISuperObject;
  OutFlag: string;
begin
  Result := false;

  OutFlag:=IfThen(AOutBox, '1', '0');
  //0926 TODO: For Outbox processing there must be IdLastMessageOut variable or message array must be pre-sorted before
  // firing OnMessage handler


                                       //TODO: time_offset - param
                                       //TODO: ! There may be be situation in which old not-delivered messages are ignored
   {
    xml:=VkApiCall(
      Format(
    'https://api.vk.com/method/messages.get.xml?v=3.0&access_token=%s&out=%s', [ApiToken, OutFlag]));
    }
  if ApiCallJsonFmt('messages.getHistory', '', LResponse, [], VKAPIVER5_80) then
  try
    //Result:=ParseMessages(xml);
  finally
  end;
end;

procedure TVKClientSession.DoOnLog(const str: string);
begin
  if Assigned(OnLog) then
    OnLog(str);
end;

procedure TVKClientSession.DoOnTokenNotify(bAuthorized: Boolean);
begin
  if Assigned(OnTokenNotify) then
    OnTokenNotify(bAuthorized);
end;

function TVKClientSession.DoVkApiCall(sUrl: string; slPost: TStringList = nil):
    TjanXMLParser2;
var
  sXml: string;
  xml: TjanXMLParser2;
begin
  Result:=nil;

  if bVkApiLog then
  begin
    DoOnLog('VKAPI Call: '+sUrl);
    if Assigned(slPost) then
      DoOnLog(slPost.Text);
  end;

  //if isDbg and dbgInGetPerson then
  //  raise Exception.Create('Fake Socket Exception');

  sXml:=HttpMethodSSL(sUrl, slPost);  // TODO: test with fake exception here

  xml:=TjanXMLParser2.Create;
  try
    xml.xml:=UnicodeToAnsiEscape(sXMl); //TODO: since parser is not-unicode - Escape NON-ANSI here
  except
    xml.Free;
    raise Exception.Create('Error parsing VK API response');
  end;

    try
      VkErrorCheck(xml);
    except
      xml.Free;
      raise;
    end;

  Result := xml;
end;

function TVKClientSession.DumpNode(Node: TjanXMLNode2): string;
var
  I: Integer;
  J: Integer;
  sInner: string;
begin
  Result := '';
  for I := 0 to Node.childCount-1 do
    begin
      sInner:=Node.childNode[I].text;

      for J := 0 to Node.childNode[I].childCount-1 do
        sInner:=sInner+DumpNode(Node.childNode[I].childNode[J]);

      if sInner<>'' then
        Result := Format('%s<%s>%s</%s>',
          [Result, Node.childNode[I].name, sInner, Node.childNode[I].name]);
    end;
end;

function TVKClientSession.EmojiTranslate_(str: string; bFromVk: boolean):
    string;
begin
  Result := str;

  if bFromVk then
  begin
    if Length(str)>1 then
      exit;                // erroneous call!

    //TODO: Range check

    Result := Format('&#%d;', [Ord(str[1])]);
  end;
end;

function TVKClientSession.EmojiTranslate(str: string; bFromVk: boolean): string;
var
  i: Integer;
  mchs: TMatchCollection;
  nMatch: Integer;
  rx: TRegEx;
  sCode: string;
  sNewText: string;
begin
  if not bFromVk then
  begin
    Result:=Emoji.EncodeEmoticons(str);
    exit;
  end;

  rx:=TRegEx.Create('(\&\#[01-9]+?;)');
  mchs:=rx.Matches(str);
  Result:=str;

  for I := 0 to mchs.Count-1 do
  begin
    sCode:=GetRxMatchGroup(mchs, 1, i);
    if Emoji.TranslateCode(sCode, sNewText) then
      Result:=StringReplace(Result, mchs.Item[i].Value, sNewText, [rfIgnoreCase, rfReplaceAll])
      else if emoji.TableName='decimal_' then
        begin
          sNewText:=StringReplace(sCode, '&#', '_', [rfIgnoreCase, rfReplaceAll]);
          Result:=StringReplace(Result, sCode, sNewText, [rfIgnoreCase, rfReplaceAll]);
        end;
      end;
  end;

procedure TVKClientSession.ForwardMessage(msg: TGateMessage; AToAddr: string);
begin
  msg.sTo:=AToAddr;
  msg.sForwardMessages:=msg.sId;
  SendMessage(msg);
end;

function TVKClientSession.GetAttachmentId(at: TjanXMLNode2): string;
begin
  Result := '';

  if at.getChildByName('aid')<>nil then
    Result := at.getChildByName('aid').text;
    // lowest priority (correct in audio, useless in photo)

  if at.getChildByName('id')<>nil then
    Result := at.getChildByName('id').text;
  if at.getChildByName('did')<>nil then
    Result := at.getChildByName('did').text;
  if at.getChildByName('pid')<>nil then
    Result := at.getChildByName('pid').text;
  if at.getChildByName('vid')<>nil then
    Result := at.getChildByName('vid').text;
end;

function TVKClientSession.GetCaptchaUrl5: string;
var
  par: TjanXmlParser2;
  sXml: string;
begin
  Result:='';

  sXml := HttpMethodSSL(
    Format('https://api.vk.com/method/account.getInfo.xml?v=5.0&access_token=%s', [ApiToken]));
  par:=TjanXmlParser2.Create;
  try
    par.XML:=sXml;
    if par.rootNode.getChildByName('redirect_uri')<>nil then
      Result:=par.rootNode.getChildByName('redirect_uri').text;

    Result:=XmlEscape(Result, false);
  finally
    FreeAndNil(par);
  end;
end;

function TVKClientSession.GetConfUserDescr(sUid: string): string;
var
  fr: TFriend;
begin // TODO: Cache users
  Result := '';

  fr:=nil;
  while not Assigned(fr) do
begin
  try
    fr:=GetPerson(sUid);
  except
      DoOnLog('GetConfUserDescr retry for '+sUid);
      Sleep(1000);
    end;
  end;


  if Assigned(fr) then
  begin
  Result := fr.sFullName;
  FreeAndNil(fr);
  end;
end;

function TVKClientSession.GetFriends: TFriendList;
var
  fl: TFriendList;
  i: integer;
  Node: TjanXMLNode2;
  sUrl: string;
  xml: TjanXMLParser2;
begin


    fl:=TFriendList.Create(true);
    Result:=fl;


    sUrl:='https://api.vk.com/method/friends.get.xml?v=3.0&fields=uid,first_name,last_name,photo,bdate&access_token=%s';
    xml:=VkApiCall(Format(sUrl, [ApiToken]));

 try
    Node := XML;//XML.getChildByName('items');

    if not Assigned(Node) then
      exit;

    for I := 0 to node.childCount-1 do
      toFriend(node.childNode[i], fl);


  finally
    FreeAndNil(xml);
  end;
end;

function TVKClientSession.GetMsgWebLink(sChatUid, sMsgId: string): string;
begin
  Result:=Format('%sim?sel=%s&msgid=%s', [GetVkUrl, sChatUid, sMsgId]);
end;

function TVKClientSession.GetMsgWebLinkByJid(AJid, AMsgId: string): string;
var
  vkId: string;
begin
  vkId:=JIdToVkUid(AJid);
  if vkId='' then
    vkId:='c'+JIdToChatId(AJid);

  Result:=GetMsgWebLink(vkId, AMsgId);
end;

function TVKClientSession.GetPerson(sAddr: string): TFriend;
var
  fl: TFriendList;
  fr: TFriend;
  sUid: string;
begin     // you are owner of Result of this function
  Result := nil;
  sUid:=JIdToVkUid(sAddr);

  if sUid='' then
    exit;

  fr:=FPersonsCache.FindByAddr(sAddr);
  if Assigned(fr) then
  begin
    Result:=fr.Duplicate;
    exit;
  end;

  dbgInGetPerson:=True;
  try
  fl:=GetPersons(sUid);
  finally
    dbgInGetPerson:=False;
  end;
  if fl.Count>0 then
    Result := fl.Items[0].Duplicate;

  FPersonsCache.Add(Result.Duplicate);

  fl.Free;
end;

function TVKClientSession.GetPersons(sUids: string): TFriendList;
var
  I: Integer;
  Node: TjanXMLNode2;
  xml: TjanXMLParser2;
begin
  Result:=nil;
  Result:=TFriendList.Create(true);

  xml:=VkApiCallFmt(
    'users.get', 'uids=%s&fields=uid,first_name,last_name,photo,bdate,online,domain',
    [sUids]);

 try
    Node := XML;//XML.getChildByName('items');

    if not Assigned(Node) then
      exit;

    for I := 0 to node.childCount-1 do
    begin
      //TODO: НЕ_В_ДРУЗЬЯХ only for those that not in friendlist
      toFriend(node.childNode[i], Result, 'VK.COM-foreign');
      //Result[i].sFullName:=Result[i].sFullName+' НЕ_В_ДРУЗЬЯХ';
      Result[i].sFullName:=Result[i].sFullName;
    end;


  finally
    FreeAndNil(xml);
  end;
end;

function TVKClientSession.GetVkUrl: string;
begin
  Result := IfThen(not IsMobileClient, 'https://vk.com/', 'https://m.vk.com/');
end;

procedure TVKClientSession.InitLongPoll;
begin
  LongPoll := TVkLongPollClient.Create(true);
  LongPoll.VkApiCallFmt:=VkApiCallFmt;
  LongPoll.OnEvent:=OnLongPollEvent;
  LongPoll.OnLog:=OnLog;
end;

procedure TVKClientSession.KeepStatus;
begin
  if Invisible then
      exit;

  try
    VkApiCall(
          Format(
          'https://api.vk.com/method/account.setOnline.xml?v=3.0&access_token=%s', [ApiToken])
          );
  except

  end;
end;

function TVKClientSession.IsReady: boolean;
begin
  Result := (sCaptchaSid='') or (sCaptchaResponse<>'');
  Result := Result and (ApiToken<>'');
end;

function TVKClientSession.JIdToVkUid(sTo: string): string;
begin
  //Result := GetRxGroup(sTo, '(?:id){0,1}(\d+?)(?:@|\z)', 1);   //this will conflict with chat addresses
  Result := GetRxGroup(sTo, 'id(-?\d+?)(?:@|\z)', 1);
end;

function TVKClientSession.JIdToChatId(sTo: string): string;
begin
  Result := GetRxGroup(sTo, 'c(\d+?)(?:@|\z)', 1);
end;

function TVKClientSession.VkIdToJid(sSrc: string; bChatId: Boolean=false): string;
begin
  if bChatId then
  Result:='c'+sSrc+'@vk.com'
    else
      Result:='id'+sSrc+'@vk.com';
end;

function TVKClientSession.Max(a, b: Integer): Integer;
begin
  if a>b then
    Result := a
    else
      Result:=b;
end;

procedure TVKClientSession.MsgMarkAsRead(const sId: string);
begin //TODO: ? persp: return bool from OnMessage, collect and send batch mids
  VkApiCallFmt('messages.markAsRead', 'mids=%s', [sId]);
end;

procedure TVKClientSession.OnLongPollEvent;
begin
  LongPollHasEvents:=true;
end;

function TVKClientSession.ParseMessages(xml: TjanXMLParser2): boolean;
var
  I: Integer;
  Node: TjanXMLNode2;
begin
  Result:=false;

  Node := XML;//.getChildByName('items');
//  repeat
    if Assigned(Node) then
    begin
      for I := node.childCount-1 downto 0 do
        if node.childNode[i].Name='message' then
          toMessage3V(node.childNode[i]);

      Result:=true;
    end;

 //    Node := Node.NextSibling;
//  until not Assigned(Node) ;


  FIdLastMessage:=Max(FIdLastMessage, FPrepareLastMessage);
end;

procedure TVKClientSession.ProcessCaptchaNeeded(xml: TjanXMLNode2);
var
  sUrl5: string;
begin                      //TODO: 5.0 compatible handler - reRequest captcha 3.0
  try
    sCaptchaResponse:='';

    if bSilentCaptchaFill then
    begin
      sSilCaptchaSid:=xml.getChildByName('captcha_sid').text;
      sSilCaptchaUrl:=xml.getChildByName('captcha_img').text;
    end
    else
      if sCaptchaSid='' then
      begin
        sCaptchaSid:=xml.getChildByName('captcha_sid').text;
        sCaptchaUrl:=xml.getChildByName('captcha_img').text;
      end;


    sUrl5:='';
    try
      sUrl5:=GetCaptchaUrl5;
    except
    end;

    if Assigned(OnCaptchaNeeded) and not bSilentCaptchaFill then
      OnCaptchaNeeded(sCaptchaSid, sCaptchaUrl, sUrl5);
  except

  end;
end;

function TVKClientSession.ParseMessageAttachments(Node: TjanXMLNode2; Msg:
    TGateMessage): string;
var
  at: TjanXMLNode2;
  atChild: TjanXMLNode2;
  atments: TjanXMLNode2;
  bKnown: Boolean;
  fwdmessages: TjanXMLNode2;
  i: Integer;
  rootMsg: TjanXMLNode2;
  sAccessKey: string;
  sAtId: string;
  sOwner: string;
  sType: string;
  //sChatUid: string;
  sHeight: string;
  sUrl: string;
  sUrlSmall: string;
  sWidth: string;
begin
  Result := '';

  rootMsg:=Node;

  while rootMsg.parentNode<>nil do
  begin
    if (rootMsg.parentNode=nil) or
      (rootMsg.parentNode.name<>'message') then
        break;

    rootMsg:=rootMsg.parentNode;
  end;


  //if rootMsg.getChildByName('mid')<>nil then
    //AMsgId:=rootMsg.getChildByName('mid').Text;
  {
  if rootMsg.getChildByName('uid')<>nil then
    sChatUid:=rootMsg.getChildByName('uid').text;
  if rootMsg.getChildByName('chat_id')<>nil then
    sChatUid:='c'+rootMsg.getChildByName('chat_id').text;
   }
  fwdmessages:=Node.getChildByName('fwd_messages');
  if Assigned(fwdmessages) then
    Result :=
    //'Цитата:'+CR+
    //'--'+CR+
    ProcessAttachedFwdMessages(fwdmessages, msg)
    //+CR
    //+'--Конец цитаты'+CR
    +':'+CR
    ;

  atments:=Node.getChildByName('attachments');
  if not Assigned(atments) then
    exit;

  if Assigned(Msg) then       // Msg is nil when parsing fwd messages
    Msg.HasAttachments:=True;

  i:=0;
  while i<atments.childCount do
  begin
    Result:=Result+CR;
    bKnown:=false;
    at:=atments.childNode[i];
    sType:='';
    try
      if at.getChildByName('type')=nil then
        continue;

     { if at.getChildByName('type').text='wall' then
      begin
        if at.getChildByName('attachments')<>nil then
          Result:=Result+CR+DumpNode(at.getChildByName('attachments'));

        continue;
      end;   }

      atChild:=at.getChildByName(at.getChildByName('type').text);

      if not Assigned(atChild) then
        continue;

      bKnown:=true;
      sOwner:='';


      if atChild.getChildByName('owner_id')<>nil then
        sOwner:=atChild.getChildByName('owner_id').text;
      if atChild.getChildByName('to_id')<>nil then
        sOwner:=atChild.getChildByName('to_id').text;

      sAtId:=GetAttachmentId(atChild);
      if atChild.getChildByName('access_key')<>nil then
         sAccessKey := atChild.getChildByName('access_key').text;

      //if sAtId='' then
      //  continue;


      if at.getChildByName('type')<>nil then
        sType:=at.getChildByName('type').text;

      Result:=Format('%sПриложение %s ->', [Result+CR, sType]);

   //   if sOwner<>'' then
   //   Result:=Format('%s На странице: %s%s%s_%s',
   //       [Result+CR, GetVkUrl, at.getChildByName('type').text,
   //         sOwner, sAtId]);
      Result:=Format('%s %s',
          [Result, GetMsgWebLinkByJid(msg.sFrom, msg.sId)]);


      sUrl:='';
      sUrlSmall:='';
      if sType='photo' then
      begin
        if atChild.GetChildByName('src_small')<>nil then
        begin
          sUrlSmall:=atChild.GetChildByName('src_small').text;
        end;

        if atChild.GetChildByName('src')<>nil then
        begin
          sUrlSmall:=atChild.GetChildByName('src').text;
        end;

        sUrl:=sUrlSmall;

        if atChild.GetChildByName('src_big')<>nil then
          sUrl:=atChild.GetChildByName('src_big').text;

        if atChild.GetChildByName('src_xxbig')<>nil then
          sUrl:=atChild.GetChildByName('src_xxbig').text;


        if atChild.GetChildByName('width')<>nil then
          sWidth:=atChild.GetChildByName('width').text;
        if atChild.GetChildByName('height')<>nil then
          sHeight:=atChild.GetChildByName('height').text;

        Result:=Format('%s Прямая: %s (%sx%s)', [Result+CR, sUrl, sWidth, sHeight]);

        if IsMobileClient then
          Result:=Result+' Маленькая: '+sUrlSmall;
      end;


      if sType='audio' then
      begin
        //Result:=Result+CR+at.getChildByName('performer').text+' - '+
        //  at.getChildByName('title').text+CR;
        // v 5.0

        Result:=Result+CR+' '+NodeGetChildText(atChild, 'artist')+' - '+
          NodeGetChildText(atChild, 'title')+CR;  //v3.0

      end
        else if atChild.getChildByName('title')<>nil then
          Result:=Result+CR+' '+atChild.getChildByName('title').text;

      if atChild.getChildByName('url')<>nil then
      begin
        if sType='audio' then
          Result:=Result+' Скачать:'+CR+NodeGetChildText(atChild, 'url')
          else
            Result:=Result+CR+' '+NodeGetChildText(atChild, 'url');
      end;

    finally
      if not bKnown then
        Result:=Result+CR+Format('++НЕИЗВЕСТНЫЙ ТИП ВЛОЖЕНИЯ: %s %s',
          [sType, GetMsgWebLink(msg.sFrom, msg.sId)]);

      inc(i);
    end;
  end;



  Result:=Result+CR;
end;

function TVKClientSession.ProcessAttachedFwdMessages(fwdmessages: TjanXMLNode2;
    AMsg: TGateMessage): string;
var
  i: Integer;
  mes: TjanXMLNode2;
  sBody: string;
  dt: TDateTime;
  sFullName: string;
  sFwd: string;
  sUid: string;
begin
  Result:='';
  mes:=nil;
  sBody:='';
  dt:=0;
  sFullName:='';
  sUid:='';
  i:=0;

  while i<fwdmessages.childCount do
  begin
      mes:=fwdmessages.childNode[i];
    try
      if mes.getChildByName('uid')<>nil then
        sUid:=mes.getChildByName('uid').text;

      if mes.getChildByName('date')<>nil then
        dt:=VkDateToDateTime(mes.getChildByName('date').text);

      if mes.getChildByName('body')<>nil then
      begin
        sBody  := MessageBodyTranslate(mes.getChildByName('body').text, true, true);
          try
            sBody:= ParseMessageAttachments(mes, AMsg) + sBody;
          except on e:Exception do
            DoOnLog('ParseMessageAttachments(FWD) EXCEPTION:'+e.message);
          end;
      end;

      sFullName:=QueryUserFullName(sUid); //TODO:Optimization: GetConfUserDescr + make cached
      if sFullName='' then
        sFullName:=GetVkUrl+'id'+sUid;

      sFwd:=Format('%s id%s@vk.com (%s):'+CR+'%s'+CR ,[sFullName, sUid,
        FormatDateTime('dd.mm.yyyy hh:nn:ss', dt), sBody]);

      Result:=Result+TabifyFwdBody(sFwd);

    finally
      inc(i);
    end;
  end;
end;

function TVKClientSession.ProcessNewMessages: Boolean;
var
  bByEvents: Boolean;
begin
  Result:=false;

  if LongPollHasEvents then
  begin
    LongPollHasEvents:=false; //before CheckNewMessages, it can be set to true now by TVKLongPollClient
    try
      Result:=CheckNewMessages(false); //TODO: LongPollHasEvents:=true ON ERRORs
    except
      LongPollHasEvents:=true;
    end;
  end;
end;

procedure TVKClientSession.QueryUserInfo;
var
  sUrl: string;
  xml: TjanXMLParser2;
begin

  sUrl:=Format(
    'https://api.vk.com/method/users.get.xml?v=3.0&access_token=%s',
    [ApiToken]);


  try
    xml:=TjanXMLParser2.Create;

    try
      xml:=VkApiCall(sUrl);
      if xml.name='response' then
      begin
        Uid:=xml.getChildByName('user').getChildByName('uid').text;
        sFullName:=xml.getChildByName('user').getChildByName('first_name').text+' '+
        xml.getChildByName('user').getChildByName('last_name').text;
      end;
    finally
      FreeAndNil(xml);
    end;
  except
       // don't pass exception, because
       // we want to continue XMPP auth
    on evk:EVkApi do
       DoOnLog(Format('QueryUserInfo VK API ERROR: %d %s', [evk.Error, evk.Message]));
    on e:Exception do
       DoOnLog('QueryUserInfo ERROR: '+e.Message);
  end;

  if sFullName='' then
    DoOnLog('QueryUserInfo: ОШИБКА: не удалось получить данные.');
end;

procedure TVKClientSession.RespondCaptcha(str: string);
var
  sNewToken: string;
begin
  sNewToken:=GetRxGroup(str, 'access_token=(.+?)([=?&]|\z)', 1);

  if sNewToken<>'' then
    ApiToken:=sNewToken
 { else if GetRxGroup(str, '(\d+)=(.+)', 1) then
  begin
    sCaptchaSid:=Trim(GetRxGroup(str, '(\d+)=(.+)', 1));
    sCaptchaResponse:=Trim(GetRxGroup(str, '(\d+)=(.+)', 2));
  end}
  else
  begin
    sCaptchaResponse:=str;
    VkApiCallFmt('account.getInfo', '', []);
  end;
end;

function TVKClientSession.SendMessage_(msg: TGateMessage): Boolean;
var                             //не используется
  sBody: string;
  sRet: string;
  sUid: string;
  sUrl: string;
  xml: TjanXMLParser2;
begin
  Result:=false;
  sUid:=JIdToVkUid(msg.sTo);
  sBody:=AnsiToUtf8(msg.sBody);
  // так и не разобрался с кодировкой.
  // В основной версии отправляю через post


  sUrl:=Format(
    'https://api.vk.com/method/messages.send.xml?v=3.0&user_id=%s&message=%s&guid=%s&access_token=%s',
    [sUid, sBody, msg.sId, ApiToken]);

  xml:=TjanXMLParser2.Create;

  try
    xml.xml:=HttpMethodSSL(sUrl);   //TODO change to: VkApiCall and test
    if xml.name='response' then
      Result:=true;
  finally
    xml.Free;
  end;
end;

function TVKClientSession.SendMessage(msg: TGateMessage): Boolean;
var
  sBody: string;
  sCid: string;
  slPost: TStringList;
  sRet: string;
  sUid: string;
  sUrl: string;
  xml: TjanXMLParser2;
begin
  Result:=false;
  sUid:=JIdToVkUid(msg.sTo);
  if sUid='' then
    sCid:=JIdToChatId(msg.sTo);


  msg.sBody:=EmojiTranslate(msg.sBody, false);

  sUrl:='https://api.vk.com/method/messages.send.xml';

  slPost:=TStringList.Create;
  slPost.Add('v=3.0');
  if sUid<>'' then
    slPost.Add('user_id='+sUid)
    else
      slPost.Add('chat_id='+sCid);

  slPost.Add('message='+msg.sBody);
  slPost.Add('forward_messages='+msg.sForwardMessages);
  slPost.Add('access_token='+ApiToken);

  xml:=TjanXMLParser2.Create;

  try
    xml.xml:=HttpMethodSSL(sUrl, slPost);
    if xml.name='response' then
      Result:=true;
  finally
    xml.Free;
  end;
end;

procedure TVKClientSession.SetApiToken(const Value: string);
begin
  FApiToken := Value;

  if FApiToken<>'' then
  begin
    QueryUserInfo;

    VkApiCallFmt('stats.trackVisitor', '', []);

    if Assigned(LongPoll) then
    begin
      if LongPoll.Suspended or LongPoll.Finished then
        FreeAndNil(LongPoll)
        else
        begin
          LongPoll.FreeOnTerminate:=true;
          LongPoll.Terminate;
        end;
    end;

    LongPoll := TVkLongPollClient.Create(true);
    LongPoll.VkApiCallFmt:=VkApiCallFmt;
    LongPoll.OnEvent:=OnLongPollEvent;
    LongPoll.OnLog:=OnLog;
    LongPoll.Start;

    LongPollHasEvents:=true; // force message check
  end
    else
      LongPoll.Terminate;

//  if sFullName='' then
  //  FApiToken:=''
    //else
    DoOnTokenNotify(FApiToken<>'');
end;

procedure TVKClientSession.toMessage(Node: TjanXMLNode2);
var                                  // api 5.0 ; NOT USED
  msg: TGateMessage;
begin
  msg:=TGateMessage.Create(nil);
  try
    msg.sId  := Node.getChildByName('id').text;

    if StrToInt(msg.sId)<=FIdLastMessage then
      exit;

    msg.sFrom := 'id'+Node.getChildByName('user_id').text+'@vk.com';
    msg.sBody  := Node.getChildByName('body').text;

    msg.dt := VkDateToDateTime(Node.getChildByName('date').text);
    OnMessage(msg);
  finally
    msg.Free;
  end;
end;

function TVKClientSession.VkDateToDateTime(sDate: string): TDateTime;
begin
  Result := UnixToDateTime(StrToInt64(sDate));
end;

procedure TVKClientSession.SetLastMessageId(ALast: Integer; bForce: boolean =
    false);
begin
  FPrepareLastMessage:=max(FPrepareLastMessage, ALast);
  if bForce then
    FIdLastMessage:=FPrepareLastMessage;
end;

procedure TVKClientSession.SetLongPollHasEvents(const Value: boolean);
begin
  //TODO : CS
  FLongPollHasEvents := Value;
  //dtLastLongPoll:=Now;
end;

procedure TVKClientSession.SetOnLog(const Value: TLogProc);
begin
  FOnLog := Value;
  LongPoll.OnLog:=FOnLog;
end;

function TVKClientSession.SleepRandom(maxMilliseconds: Integer):integer;
var
  ms: Integer;
begin
  gcs.Enter;
  ms:=Random(maxMilliseconds);
  gcs.Leave;
  Sleep(ms);
  Result:=ms;
end;

procedure TVKClientSession.toFriend(Node: TjanXMLNode2; fl: TFriendList;
    sGroup: string = '');
var
  fr: TFriend;
  sUid: string;
begin
  //if node.name<>'user' then
    //raise Exception.Create('Error Parsing friendlist. Not a <user> node');

  fr:=TFriend.Create;

  sUid:=node.getChildByName('uid').text;
  fr.sAddr:='id'+sUid+'@vk.com';
  fr.sFullName:=node.getChildByName('first_name').text;
  fr.sFullName:=fr.sFullName+' '+node.getChildByName('last_name').text;
  fr.sGroup:=sGroup;
  if fr.sGroup='' then
    fr.sGroup:='VK.COM';
      //QIP doesn't show the contact as online if no group specified

  //Function Help: https://vk.com/dev/users.get

  if (node.getChildByName('online')<>nil )and (node.getChildByName('online').text='1' )then
    fr.Presence:=fp_online
    else
      fr.Presence:=fp_offline;

  if (node.getChildByName('online_mobile')<>nil) and
    (node.getChildByName('online_mobile').text='1') then
    fr.IsMobile:=true;
  if (node.getChildByName('online_app')<>nil) then
    fr.AppId:=node.getChildByName('online_app').text;


  fr.vCard.sUrl:=GetVkUrl+'id'+sUid;

  if nil<>node.getChildByName('photo') then
    fr.vCard.sPhotoUrl:=Node.getChildByName('photo').text;

  fl.Add(fr);
end;

procedure TVKClientSession.toMessage3V(Node: TjanXMLNode2);
var                               //api 3.0 , active version
  bCR: Boolean;
  msg: TGateMessage;
begin
  msg:=TGateMessage.Create(nil);
  try
    msg.sId  := Node.getChildByName('mid').text;

    if StrToInt(msg.sId)<=FIdLastMessage then
      exit;

    msg.sFrom := 'id'+Node.getChildByName('uid').text+'@vk.com';

  bCR:=false;

   if Node.getChildByName('chat_id')<>nil then
    begin
      //TODO: this logic must be in VkToXmppSession
      // just  fill here fields of msg
      msg.sBody := Format('%s %s %s -> ',
        [msg.sBody, GetConfUserDescr(msg.sFrom), msg.sFrom]);
      msg.sFromPerson:=msg.sFrom;
      msg.sFrom := 'c'+Node.getChildByName('chat_id').text+'@vk.com';
      msg.sType:='groupchat';

     { msg.sBody := msg.sBody +Format(' (ОТВЕТИТЬ В ЧАТ: %s/im?sel=c%s )',
        [GetVkUrl, Node.getChildByName('chat_id').text]);
    }  bCR:=true;
    end;

  if (Node.getChildByName('title')<>nil)
    and (Node.getChildByName('title').text<>'...') then
    begin
      msg.sChatTitle:=Node.getChildByName('title').text;
      msg.sBody := msg.sBody+msg.sChatTitle;
      bCR:=true;
    end;

    if bCR then
      msg.sBody := msg.sBody+':'+CR;

    msg.sBody  := MessageBodyTranslate(msg.sBody, true, true) +
    MessageBodyTranslate(Node.getChildByName('body').text, true, true);
    try
      msg.sBody  := ParseMessageAttachments(Node, msg) + msg.sBody;
    except on e:Exception do
      DoOnLog('ParseMessageAttachments EXCEPTION:'+e.message);
    end;

    if msg.sBody='' then
      msg.sBody:='_';
    // may be there is some attached content that we are not expected
    // groundwork for the future. Let's just notify user that message was received

    msg.dt := VkDateToDateTime(Node.getChildByName('date').text);

    try
      if bSkipMarkedRead
        and (Node.getChildByName('read_state').text='1')
        and not IsOnlineMessageTime(msg.dt) then
        exit;
    except
    end;

    try
      //TODO: test IgnoreChats
      if IgnoreChats and (Node.getChildByName('chat_id')<>nil) then
        exit;

    except
    end;

    if IsMobileClient then
      msg.sBody:=StringReplace(msg.sBody, 'https://vk.com', 'https://m.vk.com',
        [rfIgnoreCase, rfReplaceAll]);

    OnMessage(msg);
  finally
    msg.Free;
  end;
end;

function TVKClientSession.MessageBodyTranslate(sBody: string; bDirection,
    bEmoji: boolean): string;
begin
  Result:='';
  Result := XmlEscape(sBody, not bDirection, bDirection);

  if bEmoji then
    Result:=EmojiTranslate(Result, bDirection);

end;

function TVKClientSession.NodeGetChildText(Node: TjanXMLNode2; const sChild:
    string): string;
begin
  Result := '';
  if Node.getChildByName(sChild)<>nil then
    Result:=Node.getChildByName(sChild).text;
end;

function TVKClientSession.QueryUserFullName(sUid: string): string;
var
  addr: string;
  fr: TFriend;                      // TODO: (?) Merge with QueryUserInfo
begin
  Result:='';

  addr:=VkIdToJid(sUid, false);

  fr:=GetPerson(addr);
  if not Assigned(fr) then
    exit;
  try
    Result:=fr.sFullName;
  finally
    fr.Free;
  end;

end;

procedure TVKClientSession.SetOffline;
begin
  try
    VkApiCall(
          Format(
          'https://api.vk.com/method/account.setOffline.xml?v=3.0&access_token=%s', [ApiToken])
          );
  except

  end;
end;

function TVKClientSession.TabifyFwdBody(sBody: string): string;
var
  I: Integer;
  sl: TStringList;
begin
  sl:=TStringList.Create;
  sl.Text:=sBody;

  for I := 0 to sl.Count-1 do
  begin
    sl.Strings[i]:='> '+sl.Strings[i];
  end;


  Result := sl.Text;

  sl.Free;
end;

class function TVKClientSession.UnicodeToAnsiEscape1(str: string): AnsiString;
var
  i: Integer;
  ordVal: Cardinal;
  Temp: AnsiString;
begin
  if false then
  //if isDbg then
  Temp := Utf8ToAnsi(str)
  else
  Temp := str;

  i:=1;
  while i<=Length(Temp) do
  begin
    if (Temp[i]='?') and (str[i]<>'?') then
    begin
      ordVal:=Ord(str[i]);
      if((Temp[i+1]='?')and(Ord(str[i+1])<>63)) then
      begin
        ordVal:=ordVal*$10000+Ord(str[i+1]);
        //ordVal:=ordVal*$100+Ord(str[i+1]);
        inc(i); //Double-question unicode to ansi translated
      end;
      if ordVal>$ffff then
        dec(ordVal, $D83BE800);

      Result:=Format('%s&#%u;', [Result, ordVal]);
    end
    else
      Result:=Result+Temp[i];
      //Result:=copy(Result, 1, i-1)+str[i]+copy(Result, i+1, Length(Result));
    inc(i);
  end;
end;

function TVKClientSession.VkApiCall(sUrl: string; slPost: TStringList = nil):
    TjanXMLParser2;
const
  EVK_TOKENEXPIRED = 5;
  EVK_TOOMANYREQUESTS = 6;
var
  bCaptchaEntered: Boolean;
  nRetries:integer;
begin
  Result:=nil;

  if (not IsReady) and not bSilentCaptchaFill then
  begin
    raise EVkApi.Create(10014, 'Not Ready'); //internal pseudo-code
    exit;
  end;


  bCaptchaEntered:=false;
  if (sCaptchaResponse<>'') and (sCaptchaSid<>'') then
  begin
    bCaptchaEntered:=true;
    sUrl:=Format('%s&captcha_sid=%s&captcha_key=%s', [sUrl, sCaptchaSid, sCaptchaResponse]);
  end;

  sCaptchaSid:='';
  nRetries:=0;

  while True do
  begin

    try
      Result:=DoVkApiCall(sUrl, slPost);

      if bCaptchaEntered and Assigned(OnCaptchaAccepted) then
        OnCaptchaAccepted;

    except
      on evk: EVkApi do
        begin
          if evk.Error=EVK_TOOMANYREQUESTS then
          begin
            DoOnLog(Format('EVK_TOOMANYREQUESTS;url:%s;count:%d;sleep:%d',
              [sUrl, nRetries, SleepRandom(500)]));

            inc(nRetries);
            continue;
          end;

          if evk.Error=EVK_TOKENEXPIRED then
          begin
            if Assigned(OnTokenNotify) then
              ApiToken:='';
              //OnTokenNotify_(false);

          end;

          raise;

        end;
    end;

    break;
  end;

end;

function TVKClientSession.VkApiCallFmt(const sMethod, sParams: string; args:
    array of const; slPost: TStringList = nil; AApiVersion: string =
    VKAPIVER3_0): TjanXMLParser2;
var
  LUrl: string;
begin
  Result:=nil;

  LUrl:=Format(sParams, args);
  LUrl:=Format('https://api.vk.com/method/%s.xml?v=%s&access_token=%s&%s' ,
    [sMethod, AApiVersion, ApiToken, LUrl]);
  Result:=VkApiCall(LUrl, slPost);
end;

function TVKClientSession.ApiCallJsonFmt(const AMethod, AParams: string; var
    AResponse: ISuperObject; args: array of const; AApiVersion: string =
    '3.0'): Boolean;
var
  LResponse: string;
  LUrl: string;
begin
  Result := False;

  LUrl:=Format(AParams, args);
  LUrl:=Format('https://api.vk.com/method/%s?v=%s&access_token=%s&%s' ,
    [AMethod, AApiVersion, ApiToken, LUrl]);

  LResponse := HttpMethodSSL(LUrl);
  AResponse := SO(LResponse);

  Result := True;
end;

procedure TVKClientSession.VkErrorCheck(xml: TjanXMLNode2);
var
  nErrCode: Integer;
  sMsg: string;
const
  EVK_CAPTCHANEEDED = 14;
begin
  //Result := false;


  nErrCode:=0;

  FakeVkErrorCheckSub(xml);


  if xml.name<>'error' then
    exit;

  //Result := true;

  nErrCode:=StrToInt(Trim(xml.getChildByName('error_code').text));

  try
    sMsg:=xml.getChildByName('error_msg').text;
  except
  end;


  if EVK_CAPTCHANEEDED=nErrCode then
    ProcessCaptchaNeeded(xml);

  raise EVkApi.Create(nErrCode, Format('VK API ERROR: %d %s', [nErrCode, sMsg]));
end;

constructor TVxEmoji.Create;
begin
  inherited Create;
  FTable := TStringList.Create();
end;

destructor TVxEmoji.Destroy;
begin
  FreeAndNil(FTable);
  inherited Destroy;
end;

function TVxEmoji.EncodeEmoticons(str: string): string;
var
 // code: Integer;
  I: Integer;
  mchs: TMatchCollection;
  pair: TArray<string>;
  rx: TRegEx;
  sCode: string;
  sNewCode: string;
 // rep: string;
begin
  if TableName='decimal_' then
  begin
    rx:=TRegEx.Create('(_[01-9]+?;)');
    mchs:=rx.Matches(str);
    for I := 0 to mchs.Count-1 do
    begin
      sCode:=GetRxMatchGroup(mchs, 1, I);
      sNewCode:=StringReplace(sCode, '_', '&#', [rfIgnoreCase, rfReplaceAll]);
      str:=StringReplace(str, sCode, sNewCode, [rfIgnoreCase, rfReplaceAll]);
    end;

  for I := 0 to FTable.Count-1 do
  begin
    pair:=GetTranslationPair(I);
    //code:=StrToInt('$'+pair[0]);
    //rep:=Char(code div $1000)+Char(code mod $1000);
    str:=StringReplace(str, pair[1], pair[0], [rfIgnoreCase, rfReplaceAll]);
  end;

  end;

  Result:=str;
end;

function TVxEmoji.GetTranslationPair(I: Integer): TArray<string>;
begin
  Result := FTable.Strings[i].Split([#9], 2);
end;

function TVxEmoji.SetTable(ATable: string): Boolean;
begin
  Result:=false;

  if ATable='' then
    exit;

  if (ATable<>'decimal')and(ATable<>'decimal_') then
  begin
  begin
    if SetTablePath(AbsPath(Format('emos\%s.txt', [ATable]))) then
    begin
      Self.FTableName:=ATable;
      Result:=true;
    end;
  end;
  end
    else
    begin
      Self.FTableName:=ATable;
      Result:=true;
    end;
end;

function TVxEmoji.SetTablePath(const Value: string): Boolean;
begin

  if Value='' then
  begin
    FTable.Clear;
    FTablePath := '';
    Result:=true;
    exit;
  end;

  try
    try
      FTable.LoadFromFile(Value);
      FTablePath := Value;
    except

    end;
  finally
    Result:=FTablePath=Value;
  end;
end;

function TVxEmoji.TranslateCode(sCode: string; var sTranslated: string):
    Boolean;
var
  I: Integer;
  pair: TArray<string>;
begin

  for I := 0 to FTable.Count-1 do
  begin
    pair:=GetTranslationPair(I);
    if pair[0]=sCode then
    begin
      sTranslated:=pair[1];
      Result:=true;
      exit;
    end;
  end;
end;

function TVxEmoji.TranslateCodeHex(sCode: string; var sTranslated: string):
    Boolean;   // NOT USED
var
  I: Integer;
  pair: TArray<string>;
begin

  for I := 0 to FTable.Count-1 do
  begin
    pair:=GetTranslationPair(I);
    if pair[0]=sCode then
    begin
      sTranslated:=pair[1];
      Result:=true;
      exit;
    end;
  end;
end;

end.

