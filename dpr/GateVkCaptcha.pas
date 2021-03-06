unit GateVkCaptcha;

interface

uses
  ac;

type
  TGateVkCaptcha = class(TObject)
  private
    FCaptchaSid: string;
    FIsProcessing: boolean;
    FImgUrl: string;
  public
    ac: TAC;
    constructor Create;
    destructor Destroy; override;
    procedure CaptchaKeyRequested(sUidOrIp, sUrl, sSid, sImgDir: string);
    procedure KeyAccepted;
    function TryGetKey: string;
    property CaptchaSid: string read FCaptchaSid;
    property IsProcessing: boolean read FIsProcessing write FIsProcessing;
  end;

implementation

uses
  GateGlobals, IdHTTP, System.Classes, System.DateUtils, System.SysUtils;

constructor TGateVkCaptcha.Create;
var
  gs: TGateStorage;
begin
  inherited;
  ac := TAC.Create(nil);
  gs:=TGateStorage.Create(nil);
  ac.Apikey:=gs.LoadValue('agApiKey');
  gs.Free;
end;

destructor TGateVkCaptcha.Destroy;
begin
  ac.Free;
  inherited Destroy;
end;

procedure TGateVkCaptcha.CaptchaKeyRequested(sUidOrIp, sUrl, sSid, sImgDir:
    string);
var
  gs: TGateStorage;
  idh: TIdHTTP;
  nUsed: Integer;
  slCapLog: TStringList;
  sLogPath: string;
  str: string;
begin
  FCaptchaSid:=sSid;
  FImgUrl:=sUrl;

  gs:=TGateStorage.Create(nil);
  slCapLog:=TStringList.Create;

  try
        sLogPath:='captchaLog\'+FormatDateTime('yymmdd', TTimeZone.Local.ToUniversalTime(Now));
        slCapLog.Text:=gs.LoadValue(sLogPath);
      //  slCapLog.Sorted:=true;
      // ???!EXCEPTION on change value try
      {  str:=Format('%s=%d',[sUidOrIp, nUsed]);
        if slCapLog.IndexOfName(sUidOrIp)<0 then
          slCapLog.Add(str)
          else
            slCapLog.Strings[slCapLog.IndexOfName(sUidOrIp)]:=str;
       }


        nUsed:=0;
        try
          nUsed:=StrToInt(slCapLog.Values[sUidOrIp]);
        except
        end;

        if nUsed>=5 then
          exit;

      try
        HttpMethodRawByte(FImgUrl, false);
        HttpMethodRawByte(FImgUrl, false); //this helps sometimes for buggy VK Captcha
      except
      end;

      ac.ImgDir:=sImgDir;

      try
        if ac.RecognizeUrl(sUrl) then
        begin
          IsProcessing:=true;
          inc(nUsed);
          slCapLog.Values[sUidOrIp]:=IntToStr(nUsed);
          gs.SaveValue(sLogPath, slCapLog.Text);
        end;
      except

      end;
 finally
  slCapLog.Free;
  gs.Free;
 end;
end;

procedure TGateVkCaptcha.KeyAccepted;
begin
  IsProcessing:=false;
end;

function TGateVkCaptcha.TryGetKey: string;
begin
  Result := ac.TryGetKey;

  if strpos(Pchar(Result),'ERROR_')<>nil then
    Result:='';

  if Result<>'' then
    IsProcessing:=false;
end;

end.
