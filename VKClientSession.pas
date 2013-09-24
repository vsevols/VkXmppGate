unit VKClientSession;

// (C) Vsevols 18.09.2013
// http://vsevols.livejournal.com
// vsevols@gmail.com

interface

uses
  libeay32, OpenSSLUtils, System.Classes, IdTCPServer, System.Contnrs,
  GateGlobals, System.SysUtils, GateXml;

type
  EVkApi = class(Exception)
  private
  public
    Error: Integer;
    constructor Create(AError: Integer; sMsg: string);
  end;

  //TVkSessionStatus = (vks_notoken, vks_ok, vks_captcha);

  TVKClientSession = class(TComponent)
  private
    FApiToken: string;
    FIdLastMessage: Integer;
    FPrepareLastMessage: Integer;
    Msgs: TObjectList;
    sApiKey: string;
    sCaptchaResponse: string;
    function DoVkApiCall(sUrl: string; slPost: TStringList = nil): TGateXmlParser;
    function ExtractAuthCode(sCode: string): string;
    function GetRxGroup(str, sRegExpr: string; nGroup: Integer): string;
    function JIdToVkUid(sTo: string): string;
    procedure SetApiToken(const Value: string);
    procedure toMessage(Node: TGateXmlNode);
    procedure toMessage3V(Node: TGateXmlNode);
    function VkApiCall(sUrl: string; slPost: TStringList = nil): TGateXmlParser;
    procedure VkApiCallFmt(const sMethod, sParams: string; args: array of const;
        slPost: TStringList = nil);
    //tcp: TIdTCPClient;
  public
    //Status: TVkSessionStatus;
    OnLog: TLogProc;
    OnMessage: procedure(msg: TGateMessage) of object;
    OnCaptchaNeeded: procedure(sImgUrl:string) of object;
    // called with false when auth error occurs
    OnTokenNotify: procedure(bAuthorized: boolean) of object;
    sApiClientId: string;
    sCaptchaSid: string;
    sFullName: string;
    Uid: string;
    constructor Create(AOwner: TComponent);
    function QueryAccessToken(sCode: string): boolean;
    function CheckNewMessages: boolean;
    function GetFriends: TFriendList;
    function IsReady: boolean;
    procedure SetOnline;
    function Max(a, b: Integer): Integer;
    procedure MsgMarkAsRead(const sId: string);
    function ParseMessages(xml: TGateXmlNode): boolean;
    procedure ProcessCaptchaNeeded(xml: TGateXmlNode);
    procedure QueryUserInfo;
    procedure RespondCaptcha(str: string);
    function SendMessage_(msg: TGateMessage): Boolean;
    function SendMessage(msg: TGateMessage): Boolean;
    function VkDateToDateTime(sDate: string): TDateTime;
    procedure SetLastMessageId(ALast: Integer; bForce: boolean = false);
    procedure SleepRandom(maxMilliseconds: Integer);
    procedure toFriend(Node: TGateXmlNode; fl: TFriendList);
    procedure VkErrorCheck(xml: TGateXmlNode);
    property ApiToken: string read FApiToken write SetApiToken;
    property IdLastMessage: Integer read FIdLastMessage;
  end;

implementation

uses
  IdURI, System.RegularExpressions, IdSSLOpenSSL,
  IdHTTP, httpsend, Vcl.Dialogs, ssl_openssl, System.DateUtils, GateFakes;

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
    Result:=sCode;
end;

function TVKClientSession.CheckNewMessages: boolean;
var
  xml: TGateXmlNode;
begin
  Result := false;

  try
                                       //TODO: time_offset - ПАРАМЕТР
    xml:=VkApiCall(
      Format(
      'https://api.vk.com/method/messages.get.xml?v=3.0&access_token=%s', [ApiToken]));

    //CheckVkError(sXml);

    Result:=ParseMessages(xml);
  finally
    FreeAndNil(xml);
  end;
end;

function TVKClientSession.DoVkApiCall(sUrl: string; slPost: TStringList = nil):
    TGateXmlParser;
var
  sXml: string;
  par: TGateXmlParser;
begin
  Result:=nil;

  sXml:=HttpMethodSSL(sUrl, slPost);

  try
    par.xml:=sXMl;
  except
    par.Free;
    raise Exception.Create('Error parsing VK API response');
  end;

    try
      VkErrorCheck(par);
    except
      par.Free;
      raise;
    end;

  Result := par;
end;

function TVKClientSession.GetFriends: TFriendList;
var
  fl: TFriendList;
  i: integer;
  Node: TGateXmlNode;
  sUrl: string;
  xml: TGateXmlNode;
begin


    fl:=TFriendList.Create(true);
    Result:=fl;


    sUrl:='https://api.vk.com/method/friends.get.xml?v=3.0&fields=uid,first_name,last_name&access_token=%s';
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

procedure TVKClientSession.SetOnline;
begin
  try
    VkApiCall(
          Format(
          'https://api.vk.com/method/account.setOnline.xml?v=3.0&access_token=%s', [ApiToken])
          );
  except

  end;
end;

function TVKClientSession.GetRxGroup(str, sRegExpr: string; nGroup: Integer):
    string;
var
  rx: TRegEx;
  sJson: string;
begin
  Result:='';

  rx:=TRegEx.Create(sRegExpr);
  if rx.IsMatch(str) then
  begin
    Result:=rx.Match(str).Groups.Item[1].Value;
  end;
end;

function TVKClientSession.IsReady: boolean;
begin
  Result := (sCaptchaSid='') or (sCaptchaResponse<>'');
  Result := Result and (ApiToken<>'');
end;

function TVKClientSession.JIdToVkUid(sTo: string): string;
begin
  Result := GetRxGroup(sTo, '(?:id){0,1}(\d+?)(?:@|\z)', 1);
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

function TVKClientSession.ParseMessages(xml: TGateXmlNode): boolean;
var
  I: Integer;
  Node: TGateXmlNode;
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

procedure TVKClientSession.ProcessCaptchaNeeded(xml: TGateXmlNode);
var
  sImgUrl: string;
begin
  try
    sCaptchaResponse:='';
    sCaptchaSid:=xml.getChildByName('captcha_sid').text;
    sImgUrl:=xml.getChildByName('captcha_img').text;
    if Assigned(OnCaptchaNeeded) then
      OnCaptchaNeeded(sImgUrl);
  except

  end;
end;

procedure TVKClientSession.QueryUserInfo;
var
  sUrl: string;
  xml: TGateXmlParser;
begin

  sUrl:=Format(
    'https://api.vk.com/method/users.get.xml?v=3.0&access_token=%s',
    [ApiToken]);


  try
    xml:=TGateXmlParser.Create;

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

procedure TVKClientSession.RespondCaptcha(str: string);
begin
  sCaptchaResponse:=str;
end;

function TVKClientSession.SendMessage_(msg: TGateMessage): Boolean;
var                             //не используется
  sBody: string;
  sRet: string;
  sUid: string;
  sUrl: string;
  xml: TGateXmlNode;
begin                    {
  Result:=false;
  sUid:=JIdToVkUid(msg.sTo);
  sBody:=AnsiToUtf8(msg.sBody);
  // так и не разобрался с кодировкой.
  // В основной версии отправляю через post


  sUrl:=Format(
    'https://api.vk.com/method/messages.send.xml?v=3.0&user_id=%s&message=%s&guid=%s&access_token=%s',
    [sUid, sBody, msg.sId, ApiToken]);

  xml:=TGateXmlNode.Create;

  try
    xml.xml:=HttpMethodSSL(sUrl);   //TODO change to: VkApiCall and test
    if xml.name='response' then
      Result:=true;
  finally
    xml.Free;
  end;          }
end;

function TVKClientSession.SendMessage(msg: TGateMessage): Boolean;
var
  sBody: string;
  slPost: TStringList;
  sRet: string;
  sUid: string;
  sUrl: string;
  par: TGateXmlParser;
begin
  Result:=false;
  sUid:=JIdToVkUid(msg.sTo);

  sUrl:='https://api.vk.com/method/messages.send.par';

  slPost:=TStringList.Create;
  slPost.Add('v=3.0');
  slPost.Add('user_id='+sUid);
  slPost.Add('message='+msg.sBody);
  slPost.Add('access_token='+ApiToken);

  par:=TGateXmlParser.Create;

  try
    par.xml:=HttpMethodSSL(sUrl, slPost);
    if par.name='response' then
      Result:=true;
  finally
    par.Free;
  end;
end;

procedure TVKClientSession.SetApiToken(const Value: string);
begin
  FApiToken := Value;

  if FApiToken<>'' then
    QueryUserInfo;

//  if sFullName='' then
  //  FApiToken:=''
    //else
    OnTokenNotify(true);
end;

procedure TVKClientSession.toMessage(Node: TGateXmlNode);
var                                  // api 5.0 ; NOT USED
  msg: TGateMessage;
begin
  msg:=TGateMessage.Create;
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

procedure TVKClientSession.SleepRandom(maxMilliseconds: Integer);
var
  ms: Integer;
begin
  gcs.Enter;
  ms:=Random(maxMilliseconds);
  gcs.Leave;
  Sleep(ms);
end;

procedure TVKClientSession.toFriend(Node: TGateXmlNode; fl: TFriendList);
var
  fr: TFriend;
begin
  //if node.name<>'user' then
    //raise Exception.Create('Error Parsing friendlist. Not a <user> node');

  fr:=TFriend.Create;

  fr.sAddr:='id'+node.getChildByName('uid').text+'@vk.com';
  fr.sFullName:=node.getChildByName('first_name').text;
  fr.sFullName:=fr.sFullName+' '+node.getChildByName('last_name').text;
  fr.sGroup:='VK.COM'; //QIP без группы не может отобразить контакт онлайн

  if node.getChildByName('online').text='1' then
    fr.Presence:=fp_online
    else
      fr.Presence:=fp_offline;

  fl.Add(fr);
end;

procedure TVKClientSession.toMessage3V(Node: TGateXmlNode);
var                               //api 3.0
  msg: TGateMessage;
begin
  msg:=TGateMessage.Create;
  try
    msg.sId  := Node.getChildByName('mid').text;

    if StrToInt(msg.sId)<=FIdLastMessage then
      exit;

    msg.sFrom := 'id'+Node.getChildByName('uid').text+'@vk.com';
    msg.sBody  := XmlEscape(Node.getChildByName('body').text, false, true);

    msg.dt := VkDateToDateTime(Node.getChildByName('date').text);
    OnMessage(msg);
  finally
    msg.Free;
  end;
end;

function TVKClientSession.VkApiCall(sUrl: string; slPost: TStringList = nil):
    TGateXmlParser;
const
  EVK_TOKENEXPIRED = 5;
  EVK_TOOMANYREQUESTS = 6;
begin
  Result:=nil;

  if not IsReady then
  begin
    raise Exception.Create('Waiting for captcha');
    exit;
  end;


  if sCaptchaResponse<>'' then
    sUrl:=Format('%s&captcha_sid=%s&captcha_key=%s', [sUrl, sCaptchaSid, sCaptchaResponse]);

  while True do
  begin

    try
      Result:=DoVkApiCall(sUrl, slPost);
    except
      on evk: EVkApi do
        begin
          if evk.Error=EVK_TOOMANYREQUESTS then
          begin
            SleepRandom(500);
            continue;
          end;

          if evk.Error=EVK_TOKENEXPIRED then
          begin
            if Assigned(OnTokenNotify) then
              OnTokenNotify(false);

          end;

          raise;

        end;
    end;

    break;
  end;

  sCaptchaSid:='';
end;

procedure TVKClientSession.VkApiCallFmt(const sMethod, sParams: string; args:
    array of const; slPost: TStringList = nil);
var
  sApiVer: string;
  sUrl: string;
begin
  sApiVer:='3.0';

  sUrl:=Format(sParams, args);
  sUrl:=Format('https://api.vk.com/method/%s.xml?v=%s&access_token=%s&%s' ,
    [sMethod, sApiVer, ApiToken, sUrl]);
  VkApiCall(sUrl, slPost)
end;

procedure TVKClientSession.VkErrorCheck(xml: TGateXmlNode);
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

constructor EVkApi.Create(AError: Integer; sMsg: string);
begin
  inherited Create(sMsg);
  Error:=AError;
end;

end.

