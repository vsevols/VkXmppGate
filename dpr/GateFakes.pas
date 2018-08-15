unit GateFakes;

interface

uses
  janXMLparser2, System.Classes;

procedure FakeVkErrorCheckSub(xml: TjanXMLNode2); overload;

function FakeHttpMethodSSL(sUrl: string; slPost: TStringList = nil; bSsl:
    boolean = true; AResponseStream: TStream = nil): string;

implementation

uses
  VKClientSession, uvsDebug;
var
  bVk14Error: boolean;

procedure FakeVkErrorCheckSub(xml: TjanXMLNode2);
begin
  EXIT;
  if not bFakes then
    exit;

   if not bVk14Error then
    exit;

   xml.Name:='error';
   //xml.text:='<error_code>14<error_code/><sid>123</sid>';
   xml.addChildByName('error_code').text:='14';
   xml.addChildByName('captcha_sid').text:='5432';
   xml.addChildByName('captcha_img').text:='https://12345';
   xml.addChildByName('error_msg').text:='Fake EVkApi 14';
end;

function FakeHttpMethodSSL(sUrl: string; slPost: TStringList = nil; bSsl:
    boolean = true; AResponseStream: TStream = nil): string;
begin
  Result:='';
  if not bFakes then
    exit;

  Result:=
  '<error>'
+'<error_code>14</error_code>'
+'<error_msg>Captcha needed</error_msg>'
+'<request_params list="true">'
+'<param>'
+'<key>oauth</key>'
+'<value>1</value>'
+'</param>'
+'<param>'
+'<key>method</key>'
+'<value>users.get.xml</value>'
+'</param>'
+'<param>'
+'<key>v</key>'
+'<value>3.0</value>'
+'</param>'
+'</request_params>'
+'<captcha_sid>912265134268</captcha_sid>'
+'<captcha_img>https://api.vk.com/captcha.php?sid=912265134268</captcha_img>'
+'<need_validation>1</need_validation>'
+'</error>';
end;

initialization
  bVk14Error:=true;

end.
