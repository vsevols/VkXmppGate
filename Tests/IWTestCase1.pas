unit IWTestCase1;

interface

uses
  Classes, SysUtils, TestFrameWork;

type
  TIWTestCase12 = class(TTestCase)
  private
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    {$IFDEF CLR}[Test]{$ENDIF}
    procedure Test;
  end;

implementation

uses
  IWTestFramework;

{ TIWTestCase12 }

procedure TIWTestCase12.SetUp;
begin
  // Setup
end;

procedure TIWTestCase12.TearDown;
begin
  // Clean up
end;

procedure TIWTestCase12.Test;
begin
//  with NewSession do try
//    with MainForm as TIWForm1 do begin

// add your test code here

//    end;
//  finally
//    Free;
//  end;
end;

initialization
  RegisterTest('', TIWTestCase12.Suite);
end.