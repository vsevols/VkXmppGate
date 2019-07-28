unit Unit1;

interface
uses
  DUnitX.TestFramework;

type

  [TestFixture]
  TMyTestObject = class(TObject) 
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
  published
    procedure TestVkProxy;
  end;

implementation

uses
  GateGlobals;

procedure TMyTestObject.Setup;
begin
end;

procedure TMyTestObject.TearDown;
begin
end;

procedure TMyTestObject.TestVkProxy;
begin
  GateGlobals.ProxyServer := '202.79.46.153';
  GateGlobals.ProxyPort := 51988;
  Assert.IsNotEmpty(HttpMethodSSL('https://vk.com'), 'HttpMethodSSL');
end;


initialization
  TDUnitX.RegisterTestFixture(TMyTestObject);
end.
