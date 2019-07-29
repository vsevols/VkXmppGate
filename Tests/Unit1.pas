unit Unit1;

interface
uses
  DUnitX.TestFramework, GateGlobals;

type

  [TestFixture]
  TMyTestObject = class(TObject) 
  strict private
    FProfile: TGateStorage;
    function GetAccessToken: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
  published
    procedure TestVkMessageSendReceive;
    procedure TestVkProxy;
  end;

implementation

uses
  System.SysUtils;

function TMyTestObject.GetAccessToken: string;
begin
  Result := FProfile.LoadValue('token');
end;

procedure TMyTestObject.Setup;
begin
  FProfile := TGateStorage.Create(nil);
  FProfile.Path :=
    AbsPath('d:\Debug\VkXmppGate\profiles\vsevpg127=AHZzZXZwZzEyNwA2ZWhyeWZncw==');
end;

procedure TMyTestObject.TearDown;
begin
  FreeAndNil(FProfile);
end;

procedure TMyTestObject.TestVkMessageSendReceive;
begin

  // TODO -cMM: TMyTestObject.TestVkMessageSendReceive default body inserted
end;

procedure TMyTestObject.TestVkProxy;
begin
  GateGlobals.ProxyServer := '149.56.133.81';
  GateGlobals.ProxyPort := 3128;
  Assert.IsNotEmpty(HttpMethodSSL('https://vk.com'), 'HttpMethodSSL');
end;


initialization
  TDUnitX.RegisterTestFixture(TMyTestObject);
end.
