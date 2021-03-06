unit ac;
 {
====================================
========== Coded by VANS ===========
====================================
 }
interface

uses
  Windows, Messages, SysUtils, Classes, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdHTTP, IdMultipartFormData;

type
  TAC = class(TComponent)
  private
    captcha_id: string;
    fapikey:string;
    fphrase:integer;
    fregsense:integer;
    fnumeric:integer;
    fcalc:integer;
    FImgDir: string;
    fmin_len:integer;
    fmax_len:integer;
    fis_russian:integer;
    pages: string;
    { Private declarations }
  protected
    { Protected declarations }
  public
    function Recognize(filename:string):string;
    function Report(id:string):boolean;
    function Getbalans(key:string):string;
    function RecognizeUrl(sUrl: string): Boolean;
    function TryGetKey: string;
    property ImgDir: string read FImgDir write FImgDir;
     { Public declarations }
  published
    property Apikey:string read fapikey write fapikey;
    property Phrase:integer read fphrase write fphrase;
    property Regsense:integer read fregsense write fregsense;
    property Numeric:integer read fnumeric write fnumeric;
    property Calc:integer read fcalc write fcalc;
    property Min_len:integer read fmin_len write fmin_len;
    property Max_len:integer read fmax_len write fmax_len;
    property Is_russian:integer read fis_russian write fis_russian;
    { Published declarations }
  constructor Create(aowner:Tcomponent);override;
  end;

procedure Register;

implementation

uses
  GateGlobals;

procedure Register;
begin
  RegisterComponents('Standard', [tac]);
end;

constructor TAC.Create(aowner:Tcomponent);
begin
inherited create(aowner);
 fphrase:=0;
  fregsense:=0;
  fnumeric:=0;
  fcalc:=0;
  fmin_len:=0;
  fmax_len:=0;
  fis_russian:=0;
end;

function TAC.Getbalans(key: string): string;
var
  HTTP: TidHTTP;
begin
result:='';
HTTP:=TidHTTP.Create(nil);
result:=HTTP.Get('http://antigate.com/res.php?key='+key+'&action=getbalance');
HTTP.Free;
end;

function TAC.Recognize(filename: string): string;
var page, tip:String;
  HTTP: TidHTTP;
    i:integer;
    multi:Tidmultipartformdatastream;
begin
Result:='';

if pos('.jpg', filename)<>0 then tip:='image/jpeg';
if pos('.gif', filename)<>0 then tip:='image/gif';
if pos('.png', filename)<>0 then tip:='image/png';

multi:=Tidmultipartformdatastream.Create;
multi.AddFormField('method','post');
multi.AddFormField('key', apikey);
multi.AddFile('file', filename, tip);
multi.AddFormField('phrase', IntToStr(fphrase));
multi.AddFormField('regsense', IntToStr(fregsense));
multi.AddFormField('numeric', IntToStr(fnumeric));
multi.AddFormField('calc', IntToStr(fcalc));
multi.AddFormField('min_len', IntToStr(fmin_len));
multi.AddFormField('max_len', IntToStr(fmax_len));
multi.AddFormField('is_russian ', IntToStr(fis_russian));
multi.AddFormField('soft_id','362');

HTTP:=TidHTTP.Create(nil);
page:=HTTP.Post('http://antigate.com/in.php', multi);
HTTP.Free;
multi.Free;

captcha_id:='';
if strpos(Pchar(page),'ERROR_')<>nil then begin result:=page; exit; end;
if strpos(Pchar(page),'OK|')<>nil then captcha_id:=Copy(page, pos('OK|', page)+length('OK|'), length(page));
if captcha_id='' then result:='ERROR: bad captcha id';

end;

function TAC.RecognizeUrl(sUrl: string): Boolean;
var
  HTTP: TidHTTP;
  ms: TMemoryStream;
  sFile: string;
  slResp: TStringList;
begin
  HTTP:=TidHTTP.Create(nil);
  ms:=TMemoryStream.Create;

  try
    http.get(sUrl, ms);
    sFile:=FImgDir+'captcha.png';
    ms.SaveToFile(sFile);
    Result:=Recognize(sFile)='';
    //Result:=true;
  except
    Result:=false;
  end;
  ms.Free;
  FreeAndNil(HTTP);
end;

function TAC.Report(id: string): boolean;
var
  HTTP: TidHTTP;
begin
HTTP:=TidHTTP.Create(nil);
  try
    HTTP.Get('http://antigate.com/res.php?key='+apikey+'&action=reportbad&id='+id);
    result:=true;
  except
  result:=false;
  end;
HTTP.Free;
end;

function TAC.TryGetKey: string;
var
  page: String;
  HTTP: TidHTTP;
begin
  result:='';


    //sleep(5000);
    HTTP:=TidHTTP.Create(nil);
    try
      page:=HTTP.Get('http://antigate.com/res.php?key='+apikey+'&action=get&id='+captcha_id);
    except
    end;
    HTTP.Free;
    if strpos(Pchar(page),'ERROR_')<>nil then
      begin result:=page; exit; end;

    if strpos(Pchar(page),'OK|')<>nil then
    begin
      result:=Copy(page, pos('OK|', page)+length('OK|'), length(page));
      exit;
    end;

end;

end.
