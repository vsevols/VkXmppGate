unit GateFakes;

interface

uses
  janXMLparser2;

procedure FakeVkErrorCheckSub(xml: TjanXMLNode2); overload;

implementation

uses
  VKClientSession, uvsDebug;
var
  bVk14Error: boolean;

procedure FakeVkErrorCheckSub(xml: TjanXMLNode2);
begin                    exit;{
  if not bFakes then
    exit;

   if not bVk14Error then
    exit;

   xml.Name:='error';
   //xml.text:='<error_code>14<error_code/><sid>123</sid>';
   xml.addChildByName('error_code').text:='14';
   xml.addChildByName('captcha_sid').text:='5432';
   xml.addChildByName('captcha_img').text:='http://12345';
   xml.addChildByName('error_msg').text:='Fake EVkApi 14';      }
end;

initialization
  bVk14Error:=true;

end.
