unit VKtoXMPPSession;

interface

uses
  System.Classes, JabberServerSession, VKClientSession, GateGlobals;

type

  TGtStatus = (gst_created, gst_vkauth, gst_online);
  TGtBotStatus = (bst_default, bst_getcode, bst_getcaptcha); // in forward-priority order

  TVKtoXmppSession = class(TComponent)
  private
    FIdleCount: Integer;
    FOnLog: TLogProc;
    JabSession: TJabberServerSession;
    profile: TGateStorage;
    sSupportRealAddr: string;
    Vk: TVkClientSession;
    Status: TGtStatus;     // not used in fact now. Must be deleted ?
    botStatus: TGtBotStatus;
    MarkMsgsRead: Boolean;
    function IsOnline: Boolean;
    procedure LoadProfileData;
    procedure BotReadMessage(msg: TGateMessage);
    function DaytimeGreeting: string;
    function GetHelpList: string;
    procedure ProcessGetCode(msg: TGateMessage);
    procedure SetOnLog(const Value: TLogProc);
    function TranslateSupportAddr(msg: TGateMessage; bToReal: Boolean):
        TGateMessage;
  public
    constructor Create(AJabSession: TJabberServerSession);
    destructor Destroy; override;
    procedure AddSupportContact(friends: TFriendList);
    procedure BotSendMessage(sBody: string; bSendLast: boolean = false);
    procedure LogLocal(const str: string);
    procedure OnVkTokenNotify(bAuthorized: Boolean);
    procedure OnIdle;
    procedure OnVkCaptchaNeeded(sImgUrl: string);
    procedure OnVkMessage(msg: TGateMessage);
    procedure OnXmppAuthorized(sLogin: string);
    function OnXmppCheckPass(sKey: string): Boolean;
    procedure OnXmppMessage(msg: TGateMessage);
    procedure UpdateContacts;
    procedure XmppAskForVkAuthCode(bIncorrect: Boolean = false);
    property OnLog: TLogProc read FOnLog write SetOnLog;
  end;

implementation

uses
  GateXml, Vcl.ExtCtrls, System.SysUtils, Vcl.Forms, uvsDebug,
  System.DateUtils;

const
  jidGateBot='xmppgate';

constructor TVKtoXmppSession.Create(AJabSession: TJabberServerSession);
begin
  inherited Create(AJabSession);

  sSupportRealAddr:='id6218430@vk.com';

  JabSession:=AJabSession;
  JabSession.OnMessage:=OnXmppMessage;
  JabSession.OnCheckPass:=OnXmppCheckPass;
  JabSession.OnAuthorized:=OnXmppAuthorized;
  JabSession.OnIdle:=OnIdle;
  Vk:=TVkClientSession.Create(Self);
  Vk.OnTokenNotify:=OnVkTokenNotify;
  Vk.OnMessage:=OnVkMessage;
  Vk.OnCaptchaNeeded:=OnVkCaptchaNeeded;
end;

destructor TVKtoXmppSession.Destroy;
begin
  OnLog(JabSession.sKey+' disconnected');
  inherited;
end;

procedure TVKtoXmppSession.AddSupportContact(friends: TFriendList);
var
  fr: TFriend;
begin
  fr:=TFriend.Create;
  fr.sAddr:='support@'+JabSession.sServerName;
  fr.sFullName:=SUPPORTNAME;
  fr.Presence:=fp_online;

  friends.Add(fr);
end;

procedure TVKtoXmppSession.BotSendMessage(sBody: string; bSendLast: boolean =
    false);
begin
  LogLocal(JabSession.sLogin+' message from bot: '+ sBody);

  if bSendLast then
    LogLocal('(SENDLAST)');
  // in fact messages can be sent only after jsst_online
  // before this time - added to MsgQueue

  JabSession.SendMessage(jidGateBot, sBody, bSendLast);
end;

function TVKtoXmppSession.IsOnline: Boolean;
begin
  Result:=(JabSession.Status=jsst_online) and Vk.IsReady();
end;

procedure TVKtoXmppSession.LoadProfileData;
begin
  Vk.ApiToken:=Trim(Profile.LoadValue('token'));

  try
    Vk.SetLastMessageId(
      StrToInt(Profile.LoadValue('LastVkMessId')), true
      );
  except
  end;

  if profile.LoadValue('alwaysmarkread')='1' then
    MarkMsgsRead:=true
    else
      MarkMsgsRead:=false;

end;

procedure TVKtoXmppSession.BotReadMessage(msg: TGateMessage);
var
  rpl: TGateMessage;
begin
  LogLocal(JabSession.sLogin+' message to bot: '+msg.sBody);

  if botStatus=bst_getcode then
  begin
    botStatus:=bst_default;
    ProcessGetCode(msg);
    exit;
  end;

  if botStatus=bst_getcaptcha then
  begin
    botStatus:=bst_default;
    vk.RespondCaptcha(Trim(msg.sBody));
    exit;
  end;

  if LowerCase(Trim(msg.sBody))='resettoken' then
  begin
    XmppAskForVkAuthCode;
    exit;
  end;

  if LowerCase(Trim(msg.sBody))='version' then
  begin
    BotSendMessage('Версия шлюза VKXMPP : '+SERVER_VER);
  {
    rpl:=msg.Reply('Версия шлюза VKXMPP : '+SERVER_VER);
    try
    JabSession.SendMessage(rpl);
    finally
      rpl.Free;
    end; }
    exit;
  end;

  if 'alwaysmarkread=1'=Trim(msg.sBody) then
  begin
    profile.SaveValue('alwaysmarkread', '1');
    BotSendMessage('Сообщения макируются прочитаннными вкл.', true);
    MarkMsgsRead:=true;
    exit;
  end;

  if 'alwaysmarkread=0'=Trim(msg.sBody) then
  begin
    profile.SaveValue('alwaysmarkread', '0');
    BotSendMessage('Сообщения макируются прочитаннными выкл.', true);
    MarkMsgsRead:=false;
    exit;
  end;

  if 'help'=Trim(msg.sBody) then
  begin
    BotSendMessage(GetHelpList, true);
    exit;
  end;

  BotSendMessage('Команда не распознана. Наберите help для списка доступных команд.');
end;

function TVKtoXmppSession.DaytimeGreeting: string;
begin
  Result := 'Доброй Вам ночи!';

  if HourOf(Now)>4 then
    Result := 'Доброе утро!';
  if HourOf(Now)>12 then
    Result := 'Добрый день!';
  if HourOf(Now)>17 then
    Result := 'Добрый вечер!';
end;

function TVKtoXmppSession.GetHelpList: string;
begin
  Result := CR+'versioninfo  //узнать версию шлюза'+CR+
  'resettoken   //пересоздать токен авторизации (не знаю, может ли это пригодиться ;) )'+CR+
  'alwaysmarkread=1  //Помечать полученные сообщения прочитаными.'+CR+
  'help //Вывести список доступных команд'+CR;
end;

procedure TVKtoXmppSession.LogLocal(const str: string);
begin            //Move ot GateCore
  AddToLog(str);
end;

procedure TVKtoXmppSession.OnVkTokenNotify(bAuthorized: Boolean);
var
  tim: TTimer;      // bAuthorized=TRUE: token changed =false: current token is invalid
begin
  if bAuthorized then
  begin
    Status:=gst_online;
    OnLog(JabSession.sLogin+'='+JabSession.sKey+';VK has/got token. UserInfo: '+vk.uid+' '+vk.sFullName);
    FIdleCount:=0; // force CL presences update
  end
    else if botStatus<bst_getcaptcha then
      XmppAskForVkAuthCode();
end;

procedure TVKtoXmppSession.OnIdle;
begin
  if IsOnline() then
  begin
    inc(FIdleCount);

    if FIdleCount>=60 then
      FIdleCount:=0;

    //if (isDbg and(FIdleCount mod 10=0)) then
    if (FIdleCount = 1) then
    begin
      vk.SetOnline;
      UpdateContacts;
    end;

    if (FIdleCount mod 3)=0 then
    begin
      vk.CheckNewMessages;
      Profile.SaveValue('LastVkMessId', IntToStr(vk.IdLastMessage));
    end;

    if sDbgSend<>'' then
    begin
      JabSession.Send(sDbgSend);
      sDbgSend:='';
    end;
  end;
end;

procedure TVKtoXmppSession.OnVkCaptchaNeeded(sImgUrl: string);
begin
  botStatus:=bst_getcaptcha;
  BotSendMessage('Введите текст изображённый на картинке: '+sImgUrl, true);
end;

procedure TVKtoXmppSession.OnVkMessage(msg: TGateMessage);
var
  msgSend: TGateMessage;
begin
  try
    msgSend:=TranslateSupportAddr(msg, false);
    JabSession.SendMessage(msgSend);
    if MarkMsgsRead then
      Vk.MsgMarkAsRead(msg.sId);
  finally
    msgSend.Free;
  end;
  Vk.SetLastMessageId(StrToInt(msg.sId));
end;

procedure TVKtoXmppSession.OnXmppAuthorized(sLogin: string);
begin

  if Vk.ApiToken='' then
    XmppAskForVkAuthCode;
end;

function TVKtoXmppSession.OnXmppCheckPass(sKey: string): Boolean;
                  //TODO: sLogin, sPass:string
var
  nTimes: Integer;
begin

  OnLog(JabSession.sLogin+'='+sKey+'; connected; ');

  profile:=TGateStorage.Create(Self);
  profile.Path:=AbsPath('profiles\'+JabSession.sLogin+'='+sKey);
  JabSession.profile:=profile;


  LoadProfileData;

  if vk.ApiToken='' then
  begin
    BotSendMessage(
      Format('Вас приветствует шлюз VKXMPPGate версия %s. Профиль %s', [SERVER_VER, JabSession.sLogin]));
    BotSendMessage(
      'Сервис находится в стадии тестирования.'+CR+
      'Если не удаётся подключиться, пишите (указывайте логин, с которым подключались):'+CR+
      'XMPP: vsevols@jabber.ru SKYPE: vsevols  ICQ: 49842217'+CR+
      'http://vk.com/id6218430 - лич. сообщение'+CR+
      'http://vsevols.livejournal.com/11841.html - можно оставлять комментарии.'+CR+
      'При полном успешном подключении контакт ____XmppGate-Support станет онлайн.'+
      ' Можно также свои замечания писать на него.'
      );
  end
    else if profile.ReadInt('timesConnected')<>1 then
    begin

      nTimes:=profile.ReadInt('timesConnected');

      BotSendMessage(Format('%s Шлюз VKXMPPGate v.%s, профиль %s',
        [DaytimeGreeting, SERVER_VER, JabSession.sLogin]), true);
      BotSendMessage('Вы подключились повторно.'+CR+
        'Возможно Вам будут интересны следующие поддерживаемые команды:'+CR
         +GetHelpList+
        'Адрес бота: xmppgate'+CR+
        'Не стесняйтесь писать на адреса тех.поддержки и оставлять комментарии:'+CR+
        'http://vsevols.livejournal.com/11841.html'
          , true);

      inc(nTimes);
      profile.WriteInt('timesConnected', nTimes);
    end;


  Result:=true;
end;

procedure TVKtoXmppSession.OnXmppMessage(msg: TGateMessage);
var
  msgSend: TGateMessage;
begin

  if msg.sTo='xmppgate' then
  begin
    BotReadMessage(msg);
    exit;
  end;

  try
    msgSend:=TranslateSupportAddr(msg, true);

    if not Vk.SendMessage(msgSend) then
      JabSession.SendingUnavailable(msg);
  finally
    msgSend.Free;
  end;
end;

procedure TVKtoXmppSession.ProcessGetCode(msg: TGateMessage);
begin
    Status:=gst_vkauth;
    if not vk.QueryAccessToken(msg.sBody) then
      XmppAskForVkAuthCode(true)
      else
        if vk.ApiToken<>'' then
        begin
          BotSendMessage(
            Format(
            'Аутентификация VK пройдена. Токен аккаунта %s привязан к этой паре логин-пасс.'+CR+
            'Если Ваш список контактов не отобразился - переподключитесь.', [vk.sFullName])
            );

          Profile.SaveValue('token', vk.ApiToken);
          Profile.SaveValue('uid', vk.uid);
        end;

end;

procedure TVKtoXmppSession.SetOnLog(const Value: TLogProc);
begin
  FOnLog := Value;
  JabSession.OnLog:=FOnLog;
  Vk.OnLog:=FOnLog;
end;

function TVKtoXmppSession.TranslateSupportAddr(msg: TGateMessage; bToReal:
    Boolean): TGateMessage;
var
  msgDup: TGateMessage;
begin
  msgDup:=msg.Duplicate;

  if bToReal then
  begin
    if msgDup.sTo='support@'+JabSession.sServerName then
      msgDup.sTo:=sSupportRealAddr;
  end
  else
  begin
    if msgDup.sFrom=sSupportRealAddr then
      msgDup.sFrom:='support@'+JabSession.sServerName;
  end;

  Result:=msgDup;
end;

procedure TVKtoXmppSession.UpdateContacts;
var
  friends: TFriendList;
begin
  friends:=vk.GetFriends;

  if friends.Count>1 then // prevent unsuccessfull retrieved list saving
    JabSession.SaveFriends(friends);

  AddSupportContact(friends);
  JabSession.UpdatePresences(friends);

  friends.Free;
end;

procedure TVKtoXmppSession.XmppAskForVkAuthCode(bIncorrect: Boolean = false);
begin
  botStatus:=bst_getcode;
  if bIncorrect then
    BotSendMessage('Не удалось пройти аутентификацию VK');

  BotSendMessage(
    Format(
      'Нажмите на ссылку и скопируйте адрес, на который будет перенаправлен браузер.'+cr+
      'https://oauth.vk.com/authorize?client_id=%s&redirect_uri=https://oauth.vk.com/blank.html&scope=messages,offline&display=wap&responce_type=token',
        [Vk.sApiClientId])
        );
end;

end.
