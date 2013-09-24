unit GateFakes;

interface

uses
  GateXml;

procedure FakeVkErrorCheckSub(xml: TGateXmlNode); overload;

implementation

uses
  VKClientSession, uvsDebug;
var
  bVk14Error: boolean;

procedure FakeVkErrorCheckSub(xml: TGateXmlNode);
begin
  if not bFakes then
    exit;

   if not bVk14Error then
    exit;

   xml.Name:='error';

   {
   xml.addChildByName('error_code').text:='14';
   xml.addChildByName('captcha_sid').text:='5432';
   xml.addChildByName('captcha_img').text:='http://12345';
   xml.addChildByName('error_msg').text:='Fake EVkApi 14';}
end;

initialization
  bVk14Error:=true;

end.
