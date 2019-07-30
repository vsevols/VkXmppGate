unit Unit1;

interface
uses
  DUnitX.TestFramework, GateGlobals, VKClientSession;

type

  [TestFixture]
  TMyTestObject = class(TObject)
  strict private
    FProfile: TGateStorage;
    FVk: TVkClientSession;
    function GetAccessToken: string;
    procedure InitVk;
    procedure VkMessage(AMsg: TGateMessage);
  private
    FMsg: TGateMessage;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
  published
    procedure RequestAccessToken;
    procedure TestVkMessageSendReceive;
    procedure TestVkProxy;
  end;

implementation

uses
  System.SysUtils, SafeUnit, Vcl.Forms, Vcl.Dialogs;

function TMyTestObject.GetAccessToken: string;
begin
  Result := FProfile.LoadValue('token');
end;

procedure TMyTestObject.InitVk;
begin
  FVk := TVkClientSession.Create(nil);
end;

procedure TMyTestObject.RequestAccessToken;
var
  LInput: array of string;
begin
  InitVk;
  ShellExecute(FVk.GetOAuthLink);

  SetLength(LInput, 1);
  if not InputQuery('Copy url', ['Copy url'], LInput) then
    Assert.Fail('Canceled');

  if FVk.QueryAccessToken(LInput[0]) then
    FProfile.SaveValue('token', FVk.ApiToken);
end;

procedure TMyTestObject.Setup;
begin
  GateGlobals.ProxyServer := '149.56.133.81';
  GateGlobals.ProxyPort := 3128;
  FProfile := TGateStorage.Create(nil);
  FProfile.Path :='d:\Debug\VkXmppGate\profiles\vsevpg127=AHZzZXZwZzEyNwA2ZWhyeWZncw==';
  SafeFreeAndNil(FMsg);
end;

procedure TMyTestObject.TearDown;
begin
  SafeFreeAndNil(FMsg);
  FreeAndNil(FProfile);
end;

procedure TMyTestObject.TestVkMessageSendReceive;
var
  LMsg: TGateMessage;
begin
  InitVk;
  LMsg := TGateMessage.Create(nil);
  try
    FVk.ApiToken:=Trim(FProfile.LoadValue('token'));
    LMsg.sBody := Format('TMyTestObject.TestVkMessageSendReceive %d', [Random(MaxInt)]);
    LMsg.sTo:=FVk.Uid;
    FVk.SendMessage(LMsg);
    FVk.OnMessage:=VkMessage;
    while not Assigned(FMsg) or (FMsg.sBody <> LMsg.sBody) do
    begin
      FVk.ProcessNewMessages;
      Application.ProcessMessages;
    end;

    Assert.AreEqual(LMsg.sBody, FMsg.sBody);
  finally
    FreeAndNil(FVk);
  end;
end;

procedure TMyTestObject.TestVkProxy;
begin
  Assert.IsNotEmpty(HttpMethodSSL('https://vk.com'), 'HttpMethodSSL');
end;

procedure TMyTestObject.VkMessage(AMsg: TGateMessage);
begin
  SafeFreeAndNil(FMsg);
  FMsg := AMsg.Duplicate;
end;


initialization
  TDUnitX.RegisterTestFixture(TMyTestObject);
end.

