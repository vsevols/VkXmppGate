unit vkApi;

interface

uses
  System.SysUtils;

type
  EVkApiParse = class(Exception)
  end;

type
  EVkApi = class(Exception)
  private
  public
    Error: Integer;
    constructor Create(AError: Integer; sMsg: string);
  end;

const
  VKAPIVER3_0='3.0';
  VKAPIVER5_80='5.80';

implementation

constructor EVkApi.Create(AError: Integer; sMsg: string);
begin
  inherited Create(sMsg);
  Error:=AError;
end;

end.
