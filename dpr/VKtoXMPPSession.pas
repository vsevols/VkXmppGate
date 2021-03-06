unit VKtoXMPPSession;

interface

uses
  System.Classes, JabberServerSession, VKClientSession, GateGlobals, D7Compat,
  GateVkCaptcha;

type

  TGtStatus = (gst_created, gst_vkauth, gst_online);
  TGtBotStatus = (bst_default, bst_getcode, bst_getcaptcha); // in forward-priority order



  TVKtoXmppSession = class(TComponent)
    procedure SupportRequestLog(msg: TGateMessage);
    procedure Log(const sLog:string);
  private
    AwayAnswer: string;
    FIdleCount: Integer;
    FOnLog: TLogProc;
    JabSession: TJabberServerSession;
    profile: TGateStorage;
    sSupportRealAddr: string;
    Vk: TVkClientSession;
    Status: TGtStatus;     // not used in fact now. Must be deleted ?
    botStatus: TGtBotStatus;
    dtCreated: TDateTime;
    dtHealth: TDateTime;
    FAllIdleCount: Integer;
    Friends: TFriendList;
    gsApp: TGateStorage;
    //MarkMsgsRead: Boolean;
    MarkMsgsRead2: string;   // replace of MarkMsgsRead
    meFriend: TFriend;
    nHealthIdleCount: Integer;
    Persons: TFriendList;
    slAutoAnswered: TStringList;
    slNotAnsweredMsgs: TStringList;
    vkc: TGateVkCaptcha;
    VkReceivedMsgs: TMsgList;
    WallInRoster: Boolean;
    function IsOnline: Boolean;
    procedure LoadProfileData;
    procedure BotReadMessage(msg: TGateMessage);
    procedure BotCheckSendGreeting;
    function BotProcessBooleanFlag(sBody, sFlagName, sFlagDescr: string; var
        bFlagSet: Boolean): Boolean;
    function VkCaptchaRevertIfNeeded(var sCaptchaSid, sImgUrl: string): Boolean;
    function DaytimeGreeting: string;
    function GetHelpList: string;
    procedure AutoAnswerIfNeeded(msg: TGateMessage);
    function GetUidOrIp: string;
    procedure IdleProcessCaptcha;
    procedure MessageDelivered(msg: TGateMessage);
    procedure OnReplyMarkRead(sJid: string; bRead, bForgetIds: Boolean);
    function OnXmppGetFriend(sAddr: string): TFriend;
    procedure OnXmppStillAlive;
    procedure ProcessGetCode(msg: TGateMessage);
    procedure SetOnLog(const Value: TLogProc);
    function TranslateSupportAddr(msg: TGateMessage; bToReal: Boolean):
        TGateMessage;
  public
    ServName: string;
    constructor Create(AJabSession: TJabberServerSession);
    destructor Destroy; override;
    procedure AddStdContacts(friends: TFriendList);
    function AutoAnsweredAdd(sFrom: string): Boolean;
    procedure BotCheckSendNews;
    function BotProcessStrParam(sBody: string; const sParamName, sDescr: string;
        out sParamSet: string; AcceptVals: array of const): Boolean;
    procedure BotSendMessage(sBody: string; bSendLast: boolean = false);
    function CanAutoAnswerTo(sFrom: string): Boolean;
    procedure CheckAbandoned;
    function InArray(arr: array of const; sVal: string): boolean;
    procedure LogLocal(const str: string);
    function Min(a, b: Integer): Integer;
    procedure OnVkTokenNotify(bAuthorized: Boolean);
    procedure OnIdle;
    procedure OnIdleHealth;
    procedure OnVkCaptchaAccepted;
    procedure OnVkCaptchaNeeded(sCaptchaSid, sImgUrl, sUrl5: string);
    procedure OnVkMessage(msg: TGateMessage);
    procedure OnXmppAuthorized(sLogin: string);
    function OnXmppCheckPass(sKey: string): Boolean;
    procedure OnXmppMessage(msg: TGateMessage);
    procedure OnXmppPresShowChanged;
    function ProcessHotCommand(msg: TGateMessage; bToSupport: Boolean): Boolean;
    function ProcessSysAddrMsg(msg: TGateMessage): Boolean;
    procedure UpdateContacts;
    procedure VkAddNotAnsweredMsgs(msgs: TMsgList);
    function VKSendMessage(msg: TGateMessage; bAutoMessage: boolean = false):
        Boolean;
    procedure XmppDoAskForVkAuthCode(const sAddRights: string);
    procedure XmppAskForVkAuthCode(bIncorrect: Boolean = false);
    property OnLog: TLogProc read FOnLog write SetOnLog;
  end;

implementation

uses
  JanXmlParser2, Vcl.ExtCtrls, System.SysUtils, Vcl.Forms, uvsDebug,
  System.DateUtils, System.StrUtils, vkApi;

const
  jidGateBot='xmppgate@vkxmpp.hopto.org';
  //jidGateBot='xmppgate';

constructor TVKtoXmppSession.Create(AJabSession: TJabberServerSession);
begin
  dtCreated:=Now;

  inherited Create(AJabSession);

  sSupportRealAddr:='id6218430@vk.com';

  JabSession:=AJabSession;
  JabSession.OnMessage:=OnXmppMessage;
  JabSession.OnCheckPass:=OnXmppCheckPass;
  JabSession.OnAuthorized:=OnXmppAuthorized;
  JabSession.OnIdle:=OnIdle;
  JabSession.OnGetFriend:=OnXmppGetFriend;
  JabSession.OnPresShowChanged:=OnXmppPresShowChanged;
  JabSession.OnStillAlive:=OnXmppStillAlive;
  Vk:=TVkClientSession.Create(Self);
  Vk.OnTokenNotify:=OnVkTokenNotify;
  Vk.OnMessage:=OnVkMessage;
  Vk.OnCaptchaNeeded:=OnVkCaptchaNeeded;
  Vk.OnCaptchaAccepted:=OnVkCaptchaAccepted;



  Persons := TFriendList.Create(true);
  VkReceivedMsgs :=TMsgList.Create(true);
  slAutoAnswered := TStringList.Create();
  vkc := TGateVkCaptcha.Create();
  gsApp := TGateStorage.Create(Self);
  slNotAnsweredMsgs := TStringList.Create();
end;

destructor TVKtoXmppSession.Destroy;
var
  step: string;
begin
  try
    step:='slNotAnsweredMsgs';
    FreeAndNil(slNotAnsweredMsgs);
    step:='meFriend';
    FreeAndNil(meFriend);
    step:='vkc';
    FreeAndNil(vkc);
    step:='slAutoAnswered';
    FreeAndNil(slAutoAnswered);
    step:='Persons';
    FreeAndNil(gsApp);
    step:='gsApp';

    try
      FreeAndNil(Persons);  //TODO: exception here!
      step:='VkReceivedMsgs';
    finally
      FreeAndNil(VkReceivedMsgs);
    end;
  except on e:Exception do
    OnLog(Format('TVKtoXmppSession.Destroy EXCEPTION! step: %s ; %s', [step, e.Message]));
  end;
  OnLog(JabSession.sLogin+'='+JabSession.sKey+'; TVKtoXmppSession destroyed; IP='+JabSession.Context.Binding.PeerIP);
  try
    inherited;
  except
    OnLog(('TVKtoXmppSession.Destroy EXCEPTION in inherited!'));
  end;
end;

procedure TVKtoXmppSession.AddStdContacts(friends: TFriendList);
var
  fr: TFriend;
begin
  fr:=TFriend.Create;
  fr.sAddr:='support@'+JabSession.sServerName;
  fr.sFullName:=SUPPORTNAME;
  fr.Presence:=fp_online;

  friends.Add(fr);


  fr:=TFriend.Create;
  fr.sAddr:=jidGateBot;
  fr.sFullName:='____XmppGate-Bot';
  fr.Presence:=fp_online;

  friends.Add(fr);

  if not Assigned(meFriend) then
    try
      meFriend:=OnXmppGetFriend(vk.VkIdToJid(vk.Uid));
      //Done: optimize. Seems like this is reason of users.get big count
    except
    end;

  if Assigned(meFriend) then
    friends.Add(meFriend.Duplicate);

  if WallInRoster then
  begin
    fr:=TFriend.Create;
    fr.sAddr:='wall@vk.com';
    fr.sFullName:='��� ����� ��';
    fr.Presence:=fp_online;

    friends.Add(fr);
  end;

end;

procedure TVKtoXmppSession.BotSendMessage(sBody: string; bSendLast: boolean =
    false);
begin
  Log(' message from bot: '+ sBody);

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
var
  sl: TStringList;
  sVal: string;
begin
  Vk.Permissions:=profile.LoadValue('permissions', 'messages,offline');
  Vk.ApiToken:=Trim(Profile.LoadValue('token'));

  try
    Vk.PrepareLastMessageId(
      StrToInt(Profile.LoadValue('LastVkMessId')), true
      );
  except
  end;
             {
  if profile.LoadValue('alwaysmarkread')='0' then
    MarkMsgsRead:=false
    else
      MarkMsgsRead:=true;
              }
  MarkMsgsRead2:=profile.LoadValue('readmark', 'onreply');

  if profile.LoadValue('skipmarkedread')='1' then
    Vk.bSkipMarkedRead:=true
    else
      Vk.bSkipMarkedRead:=false;

  if profile.LoadValue('ismobileclient')='1' then
    Vk.IsMobileClient:=true
    else
      Vk.IsMobileClient:=false;

  if profile.LoadValue('ignorechats')='1' then
    Vk.IgnoreChats:=true
    else
      Vk.IgnoreChats:=false;

  if profile.LoadValue('invisible')='1' then
    Vk.Invisible:=true
    else
      Vk.Invisible:=false;

  sVal:=profile.LoadValue('awayanswer');

  if sVal='' then
    AwayAnswer:='full'
    else
      AwayAnswer:=sVal;




  WallInRoster:=profile.LoadBool('wallinroster', false);

  slNotAnsweredMsgs.Text:=profile.LoadValue('notAnsweredMsgs');
  
  Vk.Emoji.SetTable(profile.LoadValue('emotable'));

end;

procedure TVKtoXmppSession.BotReadMessage(msg: TGateMessage);
var
  bFlagSet: Boolean;
  rpl: TGateMessage;
  sParamSet: string;
  val: string;
begin
  LogLocal(JabSession.sLogin+' message to bot: '+msg.sBody);

  if botStatus=bst_getcode then
  begin
    botStatus:=bst_default;
    ProcessGetCode(msg);
    exit;
  end;

  if LowerCase(Trim(msg.sBody))='resettoken' then
  begin
    Profile.SaveValue('token', '');
    XmppAskForVkAuthCode;
    exit;
  end;

  if LowerCase(Trim(msg.sBody))='resetscope' then
  begin
    Profile.SaveValue('permissions', '');
    XmppAskForVkAuthCode;
    exit;
  end;

  if LowerCase(Trim(msg.sBody))='whatsnew' then
  begin
    BotSendMessage(gsApp.LoadValue('whatsnew', ''));
    exit;
  end;

  if botStatus=bst_getcaptcha then
  begin
    botStatus:=bst_default;
    vk.RespondCaptcha(Trim(msg.sBody));
    exit;
  end;


  if LowerCase(Trim(msg.sBody))='versioninfo' then
  begin
    BotSendMessage('������ ����� VKXMPP : '+SERVER_VER);
    exit;
  end;
  {
  if 'alwaysmarkread=1'=Trim(msg.sBody) then
  begin
    profile.SaveValue('alwaysmarkread', '1');
    BotSendMessage('��������� ����������� ������������ ���.', true);
    MarkMsgsRead:=true;
    exit;
  end;

  if 'alwaysmarkread=0'=Trim(msg.sBody) then
  begin
    profile.SaveValue('alwaysmarkread', '0');
    BotSendMessage('��������� ����������� ������������ ����.', true);
    MarkMsgsRead:=false;
    exit;
  end;
   }
  if BotProcessStrParam(msg.sBody, 'readmark', '���������� ��������� ������������',
    sParamSet, ['all', 'onreply', 'none']) then
  begin
    MarkMsgsRead2:=sParamSet;
    exit;
  end;

  if 'ismobileclient=1'=Trim(msg.sBody) then
  begin
    profile.SaveValue('ismobileclient', '1');
    BotSendMessage('����� ���������� ���.', true);
    VK.isMobileClient:=true;
    exit;
  end;

  if 'ismobileclient=0'=Trim(msg.sBody) then
  begin
    profile.SaveValue('ismobileclient', '0');
    BotSendMessage('����� ���������� ����.', true);
    VK.isMobileClient:=false;
    exit;
  end;

  if BotProcessBooleanFlag(msg.sBody, 'ignorechats', '��������� �� �����', bFlagSet) then
  begin
    vk.IgnoreChats:=bFlagSet;
    exit;
  end;

  if BotProcessBooleanFlag(msg.sBody, 'skipmarkedread',
    '���������� ����������� ���������', bFlagSet) then
  begin
    vk.bSkipMarkedRead:=bFlagSet;
    exit;
  end;

  if BotProcessBooleanFlag(msg.sBody, 'invisible', '����� �����������', bFlagSet) then
  begin
    if Vk.Invisible<>bFlagSet then
    begin
      Vk.Invisible:=bFlagSet;
      if Vk.Invisible then
        Vk.SetOffline
         // this method in fact for short period sets user online :) (why???)
         // but after about a minute user idle time is recovered to previous value
        else
          Vk.KeepStatus;
    end;

    exit;
  end;

  if BotProcessStrParam(msg.sBody, 'awayanswer', '������������',
    sParamSet, ['full', 'short', 'off']) then
  begin
    AwayAnswer:=sParamSet;
    exit;
  end;

  val:=GetRxGroup(msg.sBody, 'emotable=([^\s]+)', 1);
  if val<>'' then
  begin

    if Vk.Emoji.SetTable(val) then
    begin
      BotSendMessage('������� �����������.', true);
      profile.SaveValue('emotable', val);
    end
      else
        BotSendMessage('�� ������� ������� '+val, true);

    exit;
    
  end;

  if BotProcessBooleanFlag(msg.sBody, 'wallinroster',
    '����������� �������� "��� �����"', WallInRoster) then
    exit;
  

  if 'help'=Trim(msg.sBody) then
  begin
    BotSendMessage(GetHelpList, true);
    exit;
  end;

  BotSendMessage('������� �� ����������. �������� help ��� ������ ��������� ������.');
end;

procedure TVKtoXmppSession.BotCheckSendGreeting;
var
  nTimes: Integer;
begin

  nTimes:=profile.ReadInt('timesConnected');

  if (vk.ApiToken='') and (nTimes<=1) then
  begin
    BotSendMessage(
      Format('��� ������������ ���� VKXMPPGate ������ %s. ������� %s', [SERVER_VER, JabSession.sLogin]));
    BotSendMessage(
      //'������ ��������� � ������ ������������.'+CR+
      Format('%stopic-58410860_28964830 - ����� ���������� �������', [Vk.GetVkUrl])+CR+
      Format('%stopic-58410860_28931059 - ��� ����������� ���� ��������� ���������� ���', [Vk.GetVkUrl])+CR+
      '���� �� ������ ������������, ������:'+CR+
      '����� ��� ����������� - �� support@vkxmpp.hopto.org (____XmppGate-Support � �������-�����)'+CR+
      'XMPP: vsevols@jabber.ru SKYPE: vsevols  ICQ: 49842217'+CR+
      Format('%svkxmppgate - ������ ���������', [Vk.GetVkUrl])+CR+
      Format('%swrite6218430 ��� hackdrinkfuck@vk.com - ���. ���������', [Vk.GetVkUrl])
      );
  end
    else if nTimes>1 then
    begin

      BotSendMessage(Format('%s ���� VKXMPPGate, ������� %s',
        [DaytimeGreeting, JabSession.sLogin]), true);
      BotSendMessage('�� ������������ ��������.'+CR+
        '�������� ��� ����� ��������� ��������� �������������� �������:'+CR
         +GetHelpList+CR+
        '����� ����: '+jidGateBot+CR+
        '�� ����������� ������ �� ������ ���.��������� � ��������� �����������:'+CR+
        'http://vsevols.livejournal.com/11841.html'
          );
    end;

    inc(nTimes);
    profile.WriteInt('timesConnected', nTimes);

end;

function TVKtoXmppSession.BotProcessBooleanFlag(sBody, sFlagName, sFlagDescr:
    string; var bFlagSet: Boolean): Boolean;
begin
  Result := false;

  if sFlagName+'=1'=Trim(sBody) then
  begin
    profile.SaveValue(sFlagName, '1');
    BotSendMessage(sFlagName+' ���.', true);
    bFlagSet:=true;
    Result:=true;
  end;

  if sFlagName+'=0'=Trim(sBody) then
  begin
    profile.SaveValue(sFlagName, '0');
    BotSendMessage(sFlagName+' ����.', true);
    bFlagSet:=false;
    Result:=true;
  end;

end;

procedure TVKtoXmppSession.CheckAbandoned;
begin
  // TODO:
  // if server load is over 90%
  // check notoken time>5min and disconnect
end;

function TVKtoXmppSession.VkCaptchaRevertIfNeeded(var sCaptchaSid, sImgUrl:
    string): Boolean;
var
  dt: TDateTime;
  sl: TStringList;
begin
  Result:=false;

  sl:=TStringList.Create;
  try
    try
      sl.Text:=profile.LoadValue('captcha');
      if (Trim(sl.Strings[0])<>'') then
      begin
        dt:=StrToFloat(sl.Strings[2]);
        if MinutesBetween(dt, Now)<=7 then
        begin
          sCaptchaSid:=Trim(sl.Strings[0]);
          sImgUrl:=Trim(sl.Strings[1]);
          Result:=true;
        end;
      end;
    finally
      sl.Free;
    end;
  except
  end;

  if not Result then
    profile.SaveValue('captcha', sCaptchaSid+CR+sImgUrl+CR+FloatToStr(Now));
end;

function TVKtoXmppSession.DaytimeGreeting: string;
begin
  Result := '������ ��� ����!';

  if HourOf(Now)>=4 then
    Result := '������ ����!';
  if HourOf(Now)>=12 then
    Result := '������ ����!';
  if HourOf(Now)>=17 then
    Result := '������ �����!';
end;

function TVKtoXmppSession.GetHelpList: string;
begin
  Result := CR+
  '������ �����: '+SERVER_VER+CR+
  '������: '+ServName+CR+
  'whatsnew         //����� ����������� �������'+CR+
  'resettoken       //���� �� ��������, � ����� ���������. ��������(�����������) �������� � ������� ��.'+CR+
  Format('alwaysmarkread=0 //�� �������� � %sim ������������ ��������� ���������� �����', [vk.GetVkUrl])+CR+
  Format('readmark=(all|onreply|none) //�� �������� ���������� ��������� ������������ � %sim', [vk.GetVkUrl])+CR+
  'skipmarkedread=0 //�������� ��� ����� ���������, ���� ���� ��� ��� �������� ��� �����������'+CR+
  'ismobileclient=1 //�������� ����� ���������� ��������'+CR+
  'invisible=1      //�� ������������� ������ online ���������'+CR+
  'ignorechats=1    //������������ ��������� �� ��������������������� �����������'+CR+
  'awayanswer=(full|short|off)   //������������ ���� ������ � ������� ����������'+CR+
  Format('emotable=VkEmojiGroup  //����� ������� ������������� ����������. ��. ���������� %stopic-58410860_28931059', [Vk.GetVkUrl])+CR+
  'resetscope //�������� ����� � ������������ �������: messages,offline'+CR+
  'help //������� ������ ��������� ������'+CR+
  '.info  //�������, ������� ����� �������� � �������� � ��������������.'+CR+CR+
  Format('%stopic-58410860_28976140 - ������-�������� ������ ����������� ����', [Vk.GetVkUrl])+CR+
  CR+
  '�������������� ���� (������� ���������� ����):'+CR+
  'wallinroster=1   //���������� ������� "��� �����" ��� �������� ��������� �� �����';
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
    profile.SaveValue('token', vk.ApiToken); 
    FIdleCount:=0; // force CL presences update
  end
    else if botStatus<bst_getcaptcha then
      XmppAskForVkAuthCode();
end;

procedure TVKtoXmppSession.OnIdle;
begin
  inc(FAllIdleCount);

//  GateLog(Format('%d gs.path=%s', [FAllIdleCount, gs.Path]));

  CheckAbandoned;
  OnIdleHealth;

  if (FAllIdleCount mod 5)=0 then
  begin
    try
      IdleProcessCaptcha;
    except on e:Exception do
      Log('IdleProcessCaptcha uncaught exception: '+e.Message);
    end;
  end;

  if IsOnline() then
  begin
    inc(FIdleCount);

    if FIdleCount>=60 then
      FIdleCount:=0;

    //if (isDbg and(FIdleCount mod 10=0)) then
    if (FIdleCount = 1) then
    begin
      vk.KeepStatus;
      UpdateContacts;
    end;

    Vk.ProcessNewMessages;
    //if Vk.ProcessNewMessages then
      //Profile.SaveValue('LastVkMessId', IntToStr(vk.IdLastMessage));

    if (FIdleCount mod 3)=0 then
    begin
      //vk.CheckNewMessages;
      //Profile.SaveValue('LastVkMessId', IntToStr(vk.IdLastMessage));
    end;


    if sDbgSend<>'' then
    begin
      JabSession.Send(sDbgSend);
      sDbgSend:='';
    end;
  end;
end;

procedure TVKtoXmppSession.OnIdleHealth;
begin
  if dtHealth=0 then
  begin
    dtHealth:=Now;
    exit;
  end;

  if SecondsBetween(dtHealth, Now)>60 then
  begin
    if (nHealthIdleCount<6)then
    begin
      OnLog(JabSession.sLogin+'='+JabSession.sKey+'; '+
        Format('health: %d;seconds: %d',
          [nHealthIdleCount, SecondsBetween(dtHealth, Now)]));
      if(MinutesBetween(dtCreated, Now)>=10) then
        RestartServer(nil, nil, ServName, 'Restarting by health');
    end;

    dtHealth:=Now;
    nHealthIdleCount:=0;
  end;

  inc(nHealthIdleCount);

end;

procedure TVKtoXmppSession.AutoAnswerIfNeeded(msg: TGateMessage);
var
  msgRepl: TGateMessage;
  sDetailed: string;
  sGuess: string;
begin

  //if JabSession.UserStatus<>just_online then
  if  (JabSession.PresShow<>'away')
  and (JabSession.PresShow<>'xa')
  and (JabSession.PresShow<>'dnd') then
    exit;

  if Vk.Invisible then
    exit;

  if msg.sType='groupchat' then
    exit;

  if not CanAutoAnswerTo(msg.sFrom) then
    exit;

  if not AutoAnsweredAdd(msg.sFrom) then
    exit;

  if not IsOnlineMessageTime(msg.dt) then
    exit;

  if AwayAnswer='off' then
    exit;


  if vk.IsMobileClient then
  sGuess:=' ������ ��� ������� � �������.'
  else
    sGuess:=' ������ � ������ �� ����������.';

  if AwayAnswer='short' then
    sDetailed:=''
    else
      sDetailed:=Format(
        CR+'������ %s ��� � %s UTC+4 ��� ������.',
          [JabSession.PresShow, FormatDateTime('dd.mm hh:mm:ss', JabSession.dtPresShow)]
          );

  msgRepl:=msg.Reply(
      Format(
      '����� ������ � �� ���� �������� �� ���� ���������.%s%s'+CR+
      '( ������������� ������� VkXmppGate &#128161; )',
      [sGuess, sDetailed]
      )
    );
  try
    VKSendMessage(msgRepl, true);
    Log(Format('autoanswer to %s : %s', [msgRepl.sTo, msgRepl.sBody]));
  finally
    msgRepl.Free;
  end;

end;

function TVKtoXmppSession.AutoAnsweredAdd(sFrom: string): Boolean;
begin
  Result:=false;
  if slAutoAnswered.IndexOfName(sFrom)>-1 then
    exit;

  slAutoAnswered.Add(sFrom+'=');
  Result:=true;
end;

procedure TVKtoXmppSession.BotCheckSendNews;
var
  sl: TStringList;
  sStamp: string;
begin
  sl:=TStringList.Create;
  try
    sl.Text:=gsApp.LoadValue('forcedNews');
    if sl.Count>0 then
      sStamp:=Trim(sl.Strings[0])
      else
        sStamp:='';

    if sStamp='' then
      exit;

    if sStamp=profile.LoadValue('LastForcedNewsId') then
      exit;

    sl.Delete(0);
    BotSendMessage(sl.Text);
    profile.SaveValue('LastForcedNewsId', sStamp);
  finally
    FreeAndNil(sl);
  end;
end;

function TVKtoXmppSession.BotProcessStrParam(sBody: string; const sParamName,
    sDescr: string; out sParamSet: string; AcceptVals: array of const): Boolean;
var
  sVal: string;
begin
  Result:=false;

  sVal:=GetRxGroup(sBody, sParamName+'=([^\s]+)', 1);

  if sVal='' then
    exit;

  if InArray(AcceptVals, sVal) then
  begin
    profile.SaveValue(sParamName, sVal);
    BotSendMessage(sDescr+' -�������� �������', true);
    sParamSet:=sVal;
    Result:=true;
  end;
end;

function TVKtoXmppSession.CanAutoAnswerTo(sFrom: string): Boolean;
begin
  // groupchat considered separately when address translated
  // to msg.sType=groupchat
  Result:=sFrom<>'wall@vk.com';
end;

function TVKtoXmppSession.GetUidOrIp: string;
var
  sUidOrIp: string;
begin
  sUidOrIp:=vk.Uid;
  if sUidOrIp='' then
  begin
    sUidOrIp:=Profile.LoadValue('uid');
  end;

  if sUidOrIp='' then
  begin
    sUidOrIp:=JabSession.Context.Binding.PeerIP;
  end;

  Result:=sUidOrIp;
end;

procedure TVKtoXmppSession.IdleProcessCaptcha;
var
  sCapKey: string;
begin

  if (not vkc.IsProcessing) then
  begin
    if (vk.sCaptchaSid<>'') then
    begin
      vk.bSilentCaptchaFill:=true;
      try vk.VkApiCallFmt('users.get', '', []).Free;except end;
      vk.bSilentCaptchaFill:=false;

      if vk.sSilCaptchaSid<>'' then
        vkc.CaptchaKeyRequested(GetUidOrIp, vk.sSilCaptchaUrl, vk.sSilCaptchaSid, profile.Path);
    end;
  end
  else
    begin
      sCapKey:=vkc.TryGetKey;
      if sCapKey<>'' then
      begin
        vkc.KeyAccepted;
        Vk.sCaptchaSid:=vkc.CaptchaSid;
        Vk.RespondCaptcha(sCapKey);
      end;
    end;
end;

function TVKtoXmppSession.InArray(arr: array of const; sVal: string): boolean;
var
  I: Integer;
begin
  Result:=true;

  I:=Ord(arr[i].VType);

  for I := Low(arr) to High(arr) do
    if (arr[i].VType=vtUnicodeString)and(sVal=PWideChar(arr[I].VUnicodeString)) then
      exit;

  Result:=false;
end;

procedure TVKtoXmppSession.OnVkCaptchaNeeded(sCaptchaSid, sImgUrl, sUrl5:
    string);
var
  gs: TGateStorage;
  sUidOrIp: string;
begin

  if VkCaptchaRevertIfNeeded(sCaptchaSid, sImgUrl) then
  begin
    vk.sCaptchaSid:=sCaptchaSid;
    vk.sCaptchaUrl:=sImgUrl;
  end;

  botStatus:=bst_getcaptcha;
  BotSendMessage(

    Format(
    '�������� ��������� �� ������ %s � ��������� ���� ����� �������� �������� ��� ������� ����� ����������� �� �������� (����� �������� � �������� ������): %s'+CR+
    '������: %s'+cr+
    '����� ���������� �������: %stopic-58410860_28964830 16 ������. ���� ������ �� ������� ��������� ���� ������� resettoken'
    ,
      [sUrl5, sImgUrl, ServName, vk.GetVkUrl]), true);

    // http://vk.com/dev/need_validation


end;

procedure TVKtoXmppSession.OnVkMessage(msg: TGateMessage);
var
  msgSend: TGateMessage;
begin

  if msg.sType<>'typing' then
    VkReceivedMsgs.Add(msg.Duplicate);

  try
    msgSend:=TranslateSupportAddr(msg, false);
    JabSession.SendMessage(msgSend);
    if msg.sType='typing' then
      exit;

    AutoAnswerIfNeeded(msg);

  finally
    msgSend.Free;
  end;

  Vk.PrepareLastMessageId(StrToInt(msg.sId));
  JabSession.AliveTested:=False;
end;

procedure TVKtoXmppSession.OnXmppAuthorized(sLogin: string);
begin
   BotCheckSendNews;
  //if Vk.ApiToken='' then
    //XmppAskForVkAuthCode;
end;

function TVKtoXmppSession.OnXmppCheckPass(sKey: string): Boolean;
                  //TODO: sLogin, sPass:string

begin

  OnLog(JabSession.sLogin+'='+sKey+'; auth check; IP='+JabSession.Context.Binding.PeerIP);

  profile:=TGateStorage.Create(Self);
  profile.Path:=AbsPath('profiles\'+JabSession.sLogin+'='+sKey);
  JabSession.profile:=profile;


  LoadProfileData;

  Result:=true;
end;

function TVKtoXmppSession.OnXmppGetFriend(sAddr: string): TFriend;
begin
  Result:=nil;

  if sAddr='' then
    exit;

  if Assigned(Friends) then
    Result := Friends.FindByAddr(sAddr);

  if Assigned(Result) then
    exit;

  Result:=Persons.FindByAddr(sAddr);

  if not Assigned(Result) then
  begin
    Result:=Vk.GetPerson(sAddr);
    if Assigned(Result) then
      Persons.Add(Result);
  end;
      {
  if sAddr<>'id'+vk.Uid+'@vk.com' then
  begin
    Result.sFullName:=Result.sFullName+' ��_�_�������';
    Result.sGroup:='VK.COM-others'
  end; }
end;

procedure TVKtoXmppSession.OnXmppMessage(msg: TGateMessage);
var
  bSent: Boolean;
  bToSupport: Boolean;
  msgSend: TGateMessage;
  repl: TGateMessage;
begin
  msg.sTo:=Trim(msg.sTo);

  if (msg.sTo=jidGateBot) or (msg.sTo='xmppgate') then
  begin
    BotReadMessage(msg);
    exit;
  end;          // ? incaps to ProcessSysAddrMsg

  try
    msgSend:=TranslateSupportAddr(msg, true);
    bToSupport:=msgSend.sTo<>msg.sTo;

    try
      if ProcessHotCommand(msgSend, bToSupport) then
        exit;
      if ProcessSysAddrMsg(msgSend) then
        exit;

      bSent:=VkSendMessage(msgSend);




    except on e:EXception do
      if not bToSupport then
        raise
        else
        begin
          OnLog('OnXmppMessage ERROR: '+e.Message);
        end;
    end;

    if not bSent then
    begin
      if not bToSupport then
      begin
        JabSession.SendingUnavailable(msg);
        repl:=Msg.Reply('VkXmppGate: ���� ��������� �� ����������.');
        JabSession.SendMessage(repl);
        repl.Free;
      end
        else
        begin
          SupportRequestLog(msg);
          repl:=msg.Reply(
            '�� ��������� ������ � ���.���������. ������� ���������� �������� ��� �������� �����. �������� ������ �� ���� �������� ��'
            );

          if Trim(repl.sTo)='' then
            repl.sTo:=JabSession.sJid;
          JabSession.SendMessage(repl);
          repl.Free;
        end;

    end;
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
            '�������������� VK ��������. ����� �������� %s �������� � ���� ���� �����-����.'+CR+
            '���� ��� ������ ��������� �� ����������� - ����������� �� 10 ������ � ������������ ������.', [vk.sFullName])
            );

          Profile.SaveValue('token', vk.ApiToken);

          if vk.uid<>'' then
            Profile.SaveValue('uid', vk.uid);
        end;

end;

function TVKtoXmppSession.ProcessHotCommand(msg: TGateMessage; bToSupport:
    Boolean): Boolean;
var
  fr: TFriend;
  sAppName: string;
  sCid: string;
  sM: string;
begin
  Result:=false;

  if bToSupport then
    exit;

  if Trim(msg.sBody)='.info' then
  begin
    //TODO: needs refactoring since we have TGateAddressee class
    //TODO: create TGateAddressee.ProfileUrl;DialogUrl

    Result := true;
    sM:=IfThen(Vk.IsMobileClient, 'm.', '');
    fr:=OnXmppGetFriend(msg.sTo);

    try
      if Assigned(fr) then
      begin
        sAppName:=
        IfThen(fr.AppId='3842439', 'VkXmppGate', fr.AppId);
        sAppName:=
        IfThen(fr.AppId='3881289', 'VkXmppGate(����.������)', sAppName);
        sAppName:=
        IfThen(fr.AppId='4166906', 'VkXmppGate ������ SkyNet', sAppName);

        JabSession.SendMessage(msg.sTo,
          'VkXmppGate:'+CR+
          ' '+fr.sFullName+CR+
          Format(' �������: http://%svk.com/%s', [sM, TGateAddressee.Create(msg.sTo).FullId])+CR+
          Format(' ������: http://%svk.com/im?sel=%s', [sM, TGateAddressee.Create(msg.sTo).Id])
          +IfThen(fr.IsMobile, CR+' ���������� ���������� ��������� ������.', '')
          +IfThen(sAppName<>'', CR+' ���������� �����������: '+sAppName, '')
          );
      end
        else
        begin
          if TGateAddressee.Create(msg.sTo).typ<>adt_conference then
            exit;

          JabSession.SendMessage(msg.sTo,
            'VkXmppGate:'+CR+
            Format(' �����������: http://%svk.com/im?sel=', [sM, TGateAddressee.Create(msg.sTo).FullId])
            );
        end;
    finally
      FreeAndNil(fr);
    end;
  end;
end;

procedure TVKtoXmppSession.SetOnLog(const Value: TLogProc);
begin
  FOnLog := Value;
  JabSession.OnLog:=Log;
  Vk.OnLog:=Log;
end;

procedure TVKtoXmppSession.Log(const sLog:string);
begin
  OnLog(JabSession.sLogin+'='+JabSession.sKey+';'+sLog);
end;

function TVKtoXmppSession.Min(a, b: Integer): Integer;
begin
  if a<b then
    Result := a
    else
      Result:=b;
end;

procedure TVKtoXmppSession.MessageDelivered(msg: TGateMessage);
begin
  if msg.sId='' then
    exit; //not from VK

  if MarkMsgsRead2='all' then
      Vk.MsgMarkAsRead(msg.sId);
end;

procedure TVKtoXmppSession.OnReplyMarkRead(sJid: string; bRead, bForgetIds:
    Boolean);
begin
  if slNotAnsweredMsgs.Values[sJid]<>'' then
  begin
    vk.MsgMarkAsRead(
      TGateAddressee.Create(sJid).Id,
      slNotAnsweredMsgs.Values[sJid],
      bRead
      );
    if bForgetIds then
    begin
      slNotAnsweredMsgs.Values[sJid]:='';
      profile.SaveValue('notAnsweredMsgs', slNotAnsweredMsgs.Text);
    end;
  end;
end;

procedure TVKtoXmppSession.OnVkCaptchaAccepted;
begin
  if vk.uid='' then
    vk.QueryUserInfo;

  if vk.uid<>'' then
    Profile.SaveValue('uid', vk.uid);

  BotSendMessage('����������! ���������/����� ������ �� ���������.', true);
end;

procedure TVKtoXmppSession.OnXmppStillAlive;
var
  bDeliveredNow: Boolean;
  I: Integer;
begin

  bDeliveredNow:=False;

  for I := 0 to VkReceivedMsgs.Count-1 do
  begin
    if not VkReceivedMsgs.Items[I].Delivered then
    begin
      MessageDelivered(VkReceivedMsgs.Items[I]);
      VkReceivedMsgs.Items[I].Delivered:=true;
      bDeliveredNow:=True;
    end;
  end;

  if MarkMsgsRead2='onreply' then
    VkAddNotAnsweredMsgs(VkReceivedMsgs);

  VkReceivedMsgs.Clear;

  //Check for storage optimization
  //TODO: incapsulate to GateStorage
  if bDeliveredNow then
    Profile.SaveValue('LastVkMessId', IntToStr(vk.IdLastMessage));

end;

procedure TVKtoXmppSession.OnXmppPresShowChanged;
begin
  // TODO -cMM: TVKtoXmppSession.OnXmppPresShowChanged default body inserted
end;

function TVKtoXmppSession.ProcessSysAddrMsg(msg: TGateMessage): Boolean;
const
EVK_RIGHTS = 7;
var
  msgRepl: TGateMessage;
begin
  Result:=false;

  if msg.sTo='wall@vk.com' then
  begin
    Result:=true;
    try
      vk.WallPost(msg);
      msgRepl:=msg.Reply('��������� ������������ �� ����� �����.');
      try
        JabSession.SendMessage(msgRepl);
      finally
        msgRepl.Free;
      end;
    except on e:EVkApi do
      if e.Error=EVK_RIGHTS then
      begin
        XmppDoAskForVkAuthCode('wall');
        raise;
      end;
    end;
  end;
end;

procedure TVKtoXmppSession.SupportRequestLog(msg: TGateMessage);
var
  sl: TStringList;
begin
  sl:=TStringList.Create;
  try
    ForceDirectories(AbsPath('supreq'));
    sl.Text:=msg.sBody;
    sl.SaveToFile(
      Format('supreq\%s-%s.txt',
        [FormatDateTime('yymmdd-hhnnss', Now), JabSession.sLogin]
        )
      );
  finally
    sl.Free;
  end;
end;

function TVKtoXmppSession.TranslateSupportAddr(msg: TGateMessage; bToReal:
    Boolean): TGateMessage;
var
  msgDup: TGateMessage;
begin
  msgDup:=msg.Duplicate;

  if bToReal then
  begin
    if Trim(msgDup.sTo)='support@'+JabSession.sServerName then
      msgDup.sTo:=sSupportRealAddr;
  end
  else
  begin
    if Trim(msgDup.sFrom)=sSupportRealAddr then
      msgDup.sFrom:='support@'+JabSession.sServerName;
  end;

  Result:=msgDup;
end;

procedure TVKtoXmppSession.UpdateContacts;
var
  bSucc: Boolean;
  friends: TFriendList;
begin
  friends:=vk.GetFriends;

  bSucc:=friends.Count>1;

  AddStdContacts(friends);
  JabSession.UpdatePresences(friends);

  if bSucc then // prevent unsuccessfull retrieved list saving
  begin
    JabSession.SaveFriends(friends);
    FreeAndNil(Self.Friends);
    Self.Friends:=friends;
  end
  else
    friends.Free;
end;

procedure TVKtoXmppSession.VkAddNotAnsweredMsgs(msgs: TMsgList);
var
  I: Integer;
  sPrev: string;
begin
  sPrev:=Trim(slNotAnsweredMsgs.Text);

  for I := 0 to msgs.Count-1 do
    if msgs.Items[i].sId<>'' then
    begin
      //if slNotAnsweredMsgs.Values[msgs.Items[i].sFrom]='' then
        //slNotAnsweredMsgs.Add(msgs.Items[i].sFrom);   //TODO: !!or not needed??

      if TGateAddressee.Create(msgs.Items[i].sTo).typ=adt_conference then
        continue;
        //I didn't found the way to call messages.markAsRead for
        // conferences without message_ids param


      slNotAnsweredMsgs.Values[msgs.Items[i].sFrom]:=
        IntToStr(
          Min(
              StrToIntDef(msgs.Items[i].sId, MaxInt),
              StrToIntDef(slNotAnsweredMsgs.Values[msgs.Items[i].sFrom], MaxInt)
            )
            );
    end;

  if sPrev<>Trim(slNotAnsweredMsgs.Text) then
    profile.SaveValue('notAnsweredMsgs', slNotAnsweredMsgs.Text);
end;

function TVKtoXmppSession.VKSendMessage(msg: TGateMessage; bAutoMessage:
    boolean = false): Boolean;
begin
  Result:=Vk.SendMessage(msg);

  if not Result then
    exit;

  if (MarkMsgsRead2<>'always') or
    ((MarkMsgsRead2='onreply') and bAutoMessage) then
      OnReplyMarkRead(msg.sTo, false, false);

  if MarkMsgsRead2='none' then
    OnReplyMarkRead(msg.sTo, false, true);

end;

procedure TVKtoXmppSession.XmppDoAskForVkAuthCode(const sAddRights: string);
begin
  botStatus:=bst_getcode;

  if sAddRights<>'' then
  begin
    vk.Permissions:=vk.Permissions+','+sAddRights;
    profile.SaveValue('permissions', vk.Permissions);
    BotSendMessage(
          '�� ������� ������� ��������������� ������������ ��������� �����.'+CR+
          '���������� ��������� ���� ������� � ������ ������� ��.'+CR+
          '� ������ ���� ���������: '+sAddRights+CR+
          '������� ������ ������ ���� � ������������: resetscope'+CR+
          '����� ��������� ������ ������ ��������� ����������� ��������.'
          );
  end;


  BotSendMessage(
    Format(
      '1. ������� �� ������.'+CR+
      '2. �����������  ������.'+CR+
      '3. ���������� � ��������� ���� ����� �������� ��������'+CR+
      'https://oauth.vk.com/authorize?client_id=%s&redirect_uri=https://oauth.vk.com/blank.html&scope=%s&display=wap&responce_type=token',
        [Vk.sApiClientId, vk.Permissions])
          , true);
end;

procedure TVKtoXmppSession.XmppAskForVkAuthCode(bIncorrect: Boolean = false);
begin
  BotCheckSendGreeting;

  if bIncorrect then
    BotSendMessage('�� ������� ������ �������������� VK');

  XmppDoAskForVkAuthCode('');
end;

end.

