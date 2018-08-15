unit uTesting;

interface

procedure RunTests;

procedure IdleProcessCaptcha;

implementation

uses
  VKClientSession, System.SysUtils, uvsDebug, GateVkCaptcha;

var
  vkc :TGateVkCaptcha;
  vk: TVKClientSession;

procedure RunTests;
begin
  bFakes:=True;

  vk:=TVKClientSession.Create(nil);
  vkc := TGateVkCaptcha.Create;
  try
    try
      vk.ApiToken:='123';
    //vkc.OnCaptchaNeeded:=TestOnCaptchaNeeded;
    except
    end;
    IdleProcessCaptcha;
  finally
    FreeAndNil(vk);
    FreeAndNil(vkc);
  end;
end;

procedure IdleProcessCaptcha;
var
  sCapKey: string;
begin

  if (not vkc.IsProcessing) then
  begin
    if (vk.sCaptchaSid<>'') then
    begin
      vk.bSilentCaptchaFill:=true;
      try vk.VkApiCallFmt('users.get', '', []);except end;
      vk.bSilentCaptchaFill:=false;

      if vk.sSilCaptchaSid<>'' then
        vkc.CaptchaKeyRequested('1.1.1.1', vk.sSilCaptchaUrl, vk.sSilCaptchaSid, AbsPath('testProfile\'));
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

end.
