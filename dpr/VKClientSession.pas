unit VKClientSession;

// (C) Vsevols 2013
// http://vsevols.livejournal.com
// vsevols@gmail.com

interface

uses
  libeay32, OpenSSLUtils, System.Classes, IdTCPServer, System.Contnrs,
  janXMLparser2, GateGlobals, System.SysUtils, VkLongPollClient;

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
    FPrepareLastMessage: Integer;
    LongPoll: TVkLongPollClient;
    Msgs: TObjectList;
    sApiKey: string;
    sCaptchaResponse: string;
    function CheckNewMessages: boolean;
    procedure LongPollReCreate;
    function DoVkApiCall(sUrl: string; slPost: TStringList = nil): TjanXMLParser2;
    function ExtractAuthCode(sCode: string): string;
    function GetAttachmentId(at: TjanXMLNode2): string;
    function SlNameFromIndex(sl: TStringList; Index: Integer): string;
    function ParseMessageAttachments(Node: TjanXMLNode2): string;
    function ProcessAttachedFwdMessages(fwdmessages: TjanXMLNode2): string;
    function QueryUserFullName(sUid: string): string;
    procedure SetApiToken(const Value: string);
    procedure SetLongPollHasEvents(const Value: boolean);
    procedure SetOnLog(const Value: TLogProc);
    procedure toMessage(Node: TjanXMLNode2);
    procedure toMessage3V(Node: TjanXMLNode2);
    function MessageBodyTranslate(sBody: string; bDirection, bEmoji: boolean):
        string;
    procedure ProcessTyping;
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
    OnMessage: procedure(msg: TGateMessage) of object;
    OnCaptchaNeeded: procedure(sCaptchaSid: string; sCaptchaUrl:string; sUrl5:string) of object;
    // called with false when auth error occurs
    OnTokenNotify: procedure(bAuthorized: boolean) of object;
    Permissions: string;
    sApiClientId: string;
    sCaptchaSid: string;
    sCaptchaUrl: string;
    sFullName: string;
    slNowTyping: TStringList;
    sSilCaptchaSid: string;
    sSilCaptchaUrl: string;
    Uid: string;
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;
    function QueryAccessToken(sCode: string): boolean;
    function GetCaptchaUrl5: string;
    function GetConfUserDescr(sUid: string): string;
    function GetFriends: TFriendList;
    function GetPerson(sAddr: string): TFriend;
    function GetPersons(sUids: string): TFriendList;
    function GetVkUrl: string;
    function IsReady: boolean;
    procedure KeepStatus;
    function Max(a, b: Integer): Integer;
    procedure MsgMarkAsRead(const sId: string); overload;
    procedure MsgMarkAsRead(sUid: string; const sStartId: string; bRead: Boolean);
        overload;
    function NodeGetChildText(Node: TjanXMLNode2; const sChild: string): string;
    procedure OnLongPollEvent;
    procedure TypingAsync(sUid: string);
    function ParseMessages(xml: TjanXMLParser2): boolean;
    procedure ProcessCaptchaNeeded(xml: TjanXMLNode2);
    function ProcessNewMessages: Boolean;
    procedure QueryUserInfo;
    procedure RespondCaptcha(str: string);
    function SendMessage_(msg: TGateMessage): Boolean;
    function SendMessage(msg: TGateMessage): Boolean;
    function VkDateToDateTime(sDate: string): TDateTime;
    procedure PrepareLastMessageId(ALast: Integer; bForce: boolean = false);
    procedure SetOffline;
    function SleepRandom(maxMilliseconds: Integer):integer;
    procedure toFriend(Node: TjanXMLNode2; fl: TFriendList; sGroup: string = '');
    function VkApiCallFmt(const sMethod, sParams: string; args: array of const;
        slPost: TStringList = nil): TjanXMLParser2;
    procedure VkErrorCheck(xml: TjanXMLNode2; sMethod: string);
    procedure WallPost(msg: TGateMessage);
    property ApiToken: string read FApiToken write SetApiToken;
    property IdLastMessage: Integer read FIdLastMessage;
    property OnCaptchaAccepted: TObjProc read FOnCaptchaAccepted write
        FOnCaptchaAccepted;
    property OnLog: TLogProc read FOnLog write SetOnLog;
  end;

implementation

uses
  IdURI, IdSSLOpenSSL,
  IdHTTP, httpsend, Vcl.Dialogs, ssl_openssl, System.DateUtils, GateFakes,
  System.RegularExpressions, vkApi, uvsDebug, System.StrUtils;

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


  Emoji := TVxEmoji.Create();
  Emoji.SetTablePath(AbsPath(Format('emos\%s.txt', ['VkEmojiGroup'])));
  slNowTyping := TStringList.Create();
end;

destructor TVKClientSession.Destroy;
begin
  FreeAndNil(slNowTyping);

  try
    if not Invisible then
      VkApiCallFmt('account.setOffline', '', []).Free;
  except
  end;

  FreeAndNil(Emoji);

  if Assigned(LongPoll) then
  begin
    if not LongPoll.Suspended then
    begin
      LongPoll.FreeOnTerminate:=false;
      LongPoll.Terminate;
      LongPoll.WaitFor;
      //while not LongPoll.Suspended do
        //SleepEx(1000, false);
    end;

    FreeAndNil(LongPoll);
  end;
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
  except
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

function TVKClientSession.CheckNewMessages: boolean;
var
  xml: TjanXMLParser2;
begin
  Result := false;

  try
                                       //TODO: time_offset - param
                                       //TODO: ! There may be be situation in which old not-delivered messages are ignored
    xml:=VkApiCall(
      Format(
      'https://api.vk.com/method/messages.get.xml?v=3.0&access_token=%s', [ApiToken]));

    //CheckVkError(sXml);

    Result:=ParseMessages(xml);
  finally
    FreeAndNil(xml);
  end;
end;

procedure TVKClientSession.LongPollReCreate;
begin
  LongPoll := TVkLongPollClient.Create(true);
  LongPoll.VkApiCallFmt:=VkApiCallFmt;
  LongPoll.OnEvent:=OnLongPollEvent;
  LongPoll.OnTyping:=TypingAsync;
  LongPoll.OnLog:=OnLog;
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
    OnLog('VKAPI Call: '+sUrl);
    if Assigned(slPost) then
      OnLog(slPost.Text);
  end;

  sXml:=HttpMethodSSL(sUrl, slPost);

  xml:=TjanXMLParser2.Create;
  try
    xml.xml:=UnicodeToAnsiEscape(sXMl); //TODO: since parser is not-unicode - Escape NON-ANSI here
  except
    xml.Free;
    raise Exception.Create('Error parsing VK API response');
  end;

    try
      VkErrorCheck(xml, sUrl);
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
begin
  fr:=nil;
  if IgnoreChats then
  begin
    Result:=TGateAddressee.Create(sUid).Jid;
    exit;
    //temp. workaround
    //if we ignoring chat messages do not query names for same
    //messages on every cycle
  end;

  try
    fr:=GetPerson(sUid);   //TODO: ! optimize
    Result := fr.sFullName;
  except
  end;

  FreeAndNil(fr);
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

function TVKClientSession.GetPerson(sAddr: string): TFriend;
var
  fl: TFriendList;
  sUid: string;
begin     // you are owner of Result of this function
  Result := nil;
  sUid:=TGateAddressee.Create(sAddr).Id; // JIdToVkUid(sAddr);

  if sUid='' then
    exit;

  fl:=GetPersons(sUid);
  if fl.Count>0 then
    Result := fl.Items[0].Duplicate;

  fl.Free;
end;

function TVKClientSession.GetPersons(sUids: string): TFriendList;
var
  I: Integer;
  Node: TjanXMLNode2;
  xml: TjanXMLParser2;
begin
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
      //DONE: НЕ_В_ДРУЗЬЯХ only for those that not in friendlist
      toFriend(node.childNode[i], Result, '');
      //Result[i].sFullName:=Result[i].sFullName+' НЕ_В_ДРУЗЬЯХ';
      Result[i].sFullName:=Result[i].sFullName;
    end;


  finally
    FreeAndNil(xml);
  end;
end;

function TVKClientSession.SlNameFromIndex(sl: TStringList; Index: Integer):
    string;
var  //TODO: to child class of SL
  SepPos: Integer;
begin
  if (Index >= 0) and (Index<sl.Count) then
  begin
    Result := sl.Strings[Index];
    SepPos := AnsiPos(sl.NameValueSeparator, Result);
    if (SepPos > 0) then
      System.Delete(Result, SepPos, MaxInt)
    else
      Result := '';
  end
  else
    Result := '';
end;

function TVKClientSession.GetVkUrl: string;
begin
  Result := IfThen(not IsMobileClient, 'http://vk.com/', 'http://m.vk.com/');
end;

procedure TVKClientSession.KeepStatus;
begin
  if Invisible then
      exit;

  try
    VkApiCall(
          Format(
          'https://api.vk.com/method/account.setOnline.xml?v=3.0&access_token=%s', [ApiToken])
          ).Free;
  except

  end;
end;

function TVKClientSession.IsReady: boolean;
begin
  Result := (sCaptchaSid='') or (sCaptchaResponse<>'');
  Result := Result and (ApiToken<>'');
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
  VkApiCallFmt('messages.markAsRead', 'mids=%s', [sId]).Free;
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

function TVKClientSession.ParseMessageAttachments(Node: TjanXMLNode2): string;
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
  sChatUid: string;
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


  if rootMsg.getChildByName('uid')<>nil then
    sChatUid:=rootMsg.getChildByName('uid').text;
  if rootMsg.getChildByName('chat_id')<>nil then
    sChatUid:='c'+rootMsg.getChildByName('chat_id').text;

  fwdmessages:=Node.getChildByName('fwd_messages');
  if Assigned(fwdmessages) then
    Result := 'Цитата:'+CR+
    '--'+CR+
    ProcessAttachedFwdMessages(fwdmessages)+CR+
    '--Конец цитаты'+CR;

  atments:=Node.getChildByName('attachments');
  if not Assigned(atments) then
    exit;

  i:=0;
  while i<atments.childCount do
  begin
    Result:=Result+CR;
    bKnown:=false;
    at:=atments.childNode[i];
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

      sOwner:='';
      if atChild.getChildByName('owner_id')<>nil then
        sOwner:=atChild.getChildByName('owner_id').text;
      if atChild.getChildByName('to_id')<>nil then
        sOwner:=atChild.getChildByName('to_id').text;

      if sOwner='' then
        continue;

      sAtId:=GetAttachmentId(atChild);
      if atChild.getChildByName('access_key')<>nil then
         sAccessKey := atChild.getChildByName('access_key').text;

      if sAtId='' then
        continue;

      bKnown:=true;

      sType:='';
      if at.getChildByName('type')<>nil then
        sType:=at.getChildByName('type').text;

      Result:=Format('%sПриложение %s ->', [Result+CR, sType]);

      Result:=Format('%s На странице: %s%s%s_%s',
          [Result+CR, GetVkUrl, at.getChildByName('type').text,
            sOwner, sAtId]);
      Result:=Format('%s Диалог: %sim?sel=%s',
          [Result+CR, GetVkUrl, sChatUid]);


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
        Result:=Result+CR+Format('++НЕИЗВЕСТНЫЙ ТИП ВЛОЖЕНИЯ %s %sim?sel=%s', [sType, GetVkUrl, sChatUid]);

      inc(i);
    end;
  end;



  Result:=Result+CR;
end;

function TVKClientSession.ProcessAttachedFwdMessages(fwdmessages:
    TjanXMLNode2): string;
var
  i: Integer;
  mes: TjanXMLNode2;
  sBody: string;
  dt: TDateTime;
  sFullName: string;
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
        dt:=UnixToDateTime(StrToInt64(mes.getChildByName('date').text));

      if mes.getChildByName('body')<>nil then
      begin
        sBody  := MessageBodyTranslate(mes.getChildByName('body').text, true, true);
          try
            sBody:= ParseMessageAttachments(mes) + sBody;
          except on e:Exception do
            OnLog('ParseMessageAttachments(FWD) EXCEPTION:'+e.message);
          end;
      end;

      sFullName:=QueryUserFullName(sUid); //TODO:? (optimize) One query for all user_ids
      if sFullName='' then
        sFullName:='id'+sUid+'@vk.com';
      Result:=Format('%s%s id%s (%s): %s'+CR ,[Result, sFullName, sUid,
        FormatDateTime('dd.mm.yyyy hh:nn:ss', dt), sBody]);

    finally
      inc(i);
    end;
  end;
end;

function TVKClientSession.ProcessNewMessages: Boolean;
var
  bByEvents: Boolean;
  I: Integer;
begin
  Result:=false;

  if LongPollHasEvents then
  begin
    LongPollHasEvents:=false; //before CheckNewMessages, it can be set to true now by TVKLongPollClient
    try
      Result:=CheckNewMessages; //TODO: LongPollHasEvents:=true ON ERRORs
    except
      LongPollHasEvents:=true;
    end;
  end;


  (*TODO: extracted code
  if Assigned(LongPoll) then
  begin
    try
      LongPoll.cs.Enter
      if slNowTyping.Count>0 then
      begin
        for I := 0 to slNowTyping.Count-1 do
        begin
          msg
        end;
      end;
    finally
      LongPoll.cs.Leave;
    end;
  end;
  *)
  ProcessTyping;

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
       OnLog(Format('QueryUserInfo VK API ERROR: %d %s', [evk.Error, evk.Message]));
    on e:Exception do
       OnLog('QueryUserInfo ERROR: '+e.Message);
  end;

  if sFullName='' then
    OnLog('QueryUserInfo: ОШИБКА: не удалось получить данные.');
end;

function TVKClientSession.QueryUserFullName(sUid: string): string;
var
  sUrl: string;                      // TODO: Merge with QueryUserInfo
  xml: TjanXMLParser2;
begin

  sUrl:=Format(
    'https://api.vk.com/method/users.get.xml?v=3.0&access_token=%s&user_ids=%s',
    [ApiToken, sUid]);


  try
    xml:=TjanXMLParser2.Create;

    try
      xml:=VkApiCall(sUrl);
      if xml.name='response' then
      begin
        //Uid:=xml.getChildByName('user').getChildByName('uid').text;
        Result:=xml.getChildByName('user').getChildByName('first_name').text+' '+
        xml.getChildByName('user').getChildByName('last_name').text;
      end;
    finally
      FreeAndNil(xml);
    end;
  except
       // don't pass exception, because
       // we want to continue XMPP auth
    on evk:EVkApi do
       OnLog(Format('QueryUserInfo1 VK API ERROR: %d %s', [evk.Error, evk.Message]));
    on e:Exception do
       OnLog('QueryUserFullName ERROR: '+e.Message);
  end;

  if sFullName='' then
    OnLog('QueryUserFullName: ОШИБКА: не удалось получить данные для '+sUid);
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
    VkApiCallFmt('account.getInfo', '', []).Free;
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
  sUid:=TGateAddressee.Create(msg.sTo).Id;
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
  addr: TGateAddressee;
  sBody: string;
  slPost: TStringList;
  sRet: string;
  sUrl: string;
  xml: TjanXMLParser2;
begin
  Result:=false;
{  sUid:=JIdToVkUid(msg.sTo);
  if sUid='' then
    sCid:=JIdToChatId(msg.sTo);
 }

 addr:=TGateAddressee.Create(msg.sTo);

  msg.sBody:=EmojiTranslate(msg.sBody, false);

  if Length(msg.sBody)>4096 then
    raise EVkApi.Create(0, 'Сообщение не может содержать более 4096 символов');

  sUrl:='https://api.vk.com/method/messages.send.xml';

  slPost:=TStringList.Create;
  slPost.Add('v=3.0');

  case addr.typ of
    adt_user: slPost.Add('user_id='+addr.Id);
    adt_conference: slPost.Add('chat_id='+addr.Id);
  end;

  slPost.Add('message='+msg.sBody);
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

    if Assigned(LongPoll) then
    begin
      if LongPoll.Suspended or LongPoll.Finished then
        FreeAndNil(LongPoll)
        else
        begin
          LongPoll.FreeOnTerminate:=true;
          LongPoll.Terminate;
          LongPoll:=nil;
        end;
    end;

    LongPollReCreate;
    LongPoll.Start;

    LongPollHasEvents:=true; // force message check
  end
    else
      if Assigned(LongPoll) then
      begin
        LongPoll.FreeOnTerminate:=true;
        LongPoll.Terminate;
        LongPoll:=nil;
      end;

//  if sFullName='' then
  //  FApiToken:=''
    //else
    OnTokenNotify(FApiToken<>'');
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

procedure TVKClientSession.PrepareLastMessageId(ALast: Integer; bForce: boolean
    = false);
begin
  FPrepareLastMessage:=max(FPrepareLastMessage, ALast);
  if bForce then
    FIdLastMessage:=FPrepareLastMessage;
end;

procedure TVKClientSession.SetLongPollHasEvents(const Value: boolean);
begin
  //TODO : CS
  FLongPollHasEvents := Value;
end;

procedure TVKClientSession.SetOnLog(const Value: TLogProc);
begin
  FOnLog := Value;
  if Assigned(LongPoll) then
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
      msg.sFrom := 'c'+Node.getChildByName('chat_id').text+'@vk.com';
      msg.sType:='groupchat';

     { msg.sBody := msg.sBody +Format(' (ОТВЕТИТЬ В ЧАТ: %s/im?sel=c%s )',
        [GetVkUrl, Node.getChildByName('chat_id').text]);
    }  bCR:=true;
    end;

  if (Node.getChildByName('title')<>nil)
    and (Trim(Node.getChildByName('title').text)<>'...') then
    begin
      msg.sBody := msg.sBody+Node.getChildByName('title').text;
      bCR:=true;
    end;

    if bCR then
      msg.sBody := msg.sBody+':'+CR;

    msg.sBody  := MessageBodyTranslate(msg.sBody, true, true) +
    MessageBodyTranslate(Node.getChildByName('body').text, true, true);
    try
      msg.sBody  := ParseMessageAttachments(Node) + msg.sBody;
    except on e:Exception do
      OnLog('ParseMessageAttachments EXCEPTION:'+e.message);
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
      msg.sBody:=StringReplace(msg.sBody, 'http://vk.com', 'http://m.vk.com',
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
  Result:=UnicodeToAnsiEscape(Result); //140309 seems like MSXML unescapes unicode

  if bEmoji then
    Result:=EmojiTranslate(Result, bDirection);

end;

procedure TVKClientSession.MsgMarkAsRead(sUid: string; const sStartId: string;
    bRead: Boolean);
var
  sMethod: string;
begin
  sMethod:=IfThen(bRead, 'messages.markAsRead', 'messages.markAsNew');

  if bRead then
    VkApiCallFmt(
      sMethod, 'user_id=%s&start_message_id=%s',
      [sUid,sStartId]
        ).Free
        {
        else
        VkApiCallFmt(
          sMethod,
          'message_ids=%s',
          [sStartId]
            ).Free;       } //140911 messages.markAsNew is no longer supported

end;

function TVKClientSession.NodeGetChildText(Node: TjanXMLNode2; const sChild:
    string): string;
begin
  Result := '';
  if Node.getChildByName(sChild)<>nil then
    Result:=Node.getChildByName(sChild).text;
end;

procedure TVKClientSession.TypingAsync(sUid: string);
begin
  if slNowTyping.Values[sUid]='' then
  begin
    //slNowTyping.Add(sUid);
    slNowTyping.Values[sUid]:=FloatToStr(Now);
  end;
end;

procedure TVKClientSession.ProcessTyping;
var
  dt: TDateTime;
  I: Integer;
  msg: TGateMessage;
begin
  if Assigned(LongPoll) then
  begin
    try
      LongPoll.cs.Enter;
      if slNowTyping.Count>0 then
      begin
        I := 0;
        while i<slNowTyping.Count do
        begin
          msg:=TGateMessage.Create;
          try
            dt:=StrToFloat(slNowTyping.ValueFromIndex[i]);
            msg.sFrom:=TGateAddressee.Create(SlNameFromIndex(slNowTyping, i)).Jid;
            msg.sType:='typing';

            if SecondsBetween(dt, Now)<6 then
            begin
              inc(i);
            end
            else
              begin
                msg.sBody:='paused';
                slNowTyping.Delete(i);
              end;

            OnMessage(msg);
          finally
            msg.Free;
          end;
        end;
      end;
    finally
      LongPoll.cs.Leave;
    end;
  end;
end;

procedure TVKClientSession.SetOffline;
begin
  try
    VkApiCall(
          Format(
          'https://api.vk.com/method/account.setOffline.xml?v=3.0&access_token=%s', [ApiToken])
          ).Free;
  except

  end;
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
            OnLog(Format('EVK_TOOMANYREQUESTS;url:%s;count:%d;sleep:%d',
              [sUrl, nRetries, SleepRandom(500)]));

            inc(nRetries);
            continue;
          end;

          if evk.Error=EVK_TOKENEXPIRED then
          begin
            if Assigned(OnTokenNotify) then
              ApiToken:='';
              //OnTokenNotify(false);

          end;

          raise;

        end;
    end;

    break;
  end;

end;

function TVKClientSession.VkApiCallFmt(const sMethod, sParams: string; args:
    array of const; slPost: TStringList = nil): TjanXMLParser2;
var
  sApiVer: string;
  sUrl: string;
begin
  sApiVer:='3.0';

  sUrl:=Format(sParams, args);
  sUrl:=Format('https://api.vk.com/method/%s.xml?v=%s&access_token=%s&%s' ,
    [sMethod, sApiVer, ApiToken, sUrl]);
  Result:=VkApiCall(sUrl, slPost);
end;

procedure TVKClientSession.VkErrorCheck(xml: TjanXMLNode2; sMethod: string);
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

  raise EVkApi.Create(nErrCode, Format('VK API ERROR: %s %d %s', [sMethod, nErrCode, sMsg]));
end;

procedure TVKClientSession.WallPost(msg: TGateMessage);
var
  slParams: TStringList;
begin
  slParams:=TStringList.Create;
  try
    slParams.Values['message']:=msg.sBody;
    VkApiCallFmt('wall.post', '', [], slParams).Free;
  finally
    slParams.Free;
  end;
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

  if (ATable<>'decimal')and(ATable<>'decimal_')and(ATable<>'unicode') then
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
  Result := False;

  if Value='' then
  begin
    FTable.Clear;
    FTablePath := '';
    Exit(True);
  end;

  if not FileExists(Value) then
    Exit;

  FTable.LoadFromFile(Value);
  FTablePath := Value;
  Result:=True;
end;

function TVxEmoji.TranslateCode(sCode: string; var sTranslated: string):
    Boolean;
var
  I: Integer;
  pair: TArray<string>;
begin

  if TableName='unicode' then
  begin
    sTranslated:=AnsiUnescapeToUtf16(sCode);
    Result:=true;
    exit;
  end;

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

