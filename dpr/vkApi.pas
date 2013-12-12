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

implementation

constructor EVkApi.Create(AError: Integer; sMsg: string);
begin
  inherited Create(sMsg);
  Error:=AError;
end;

end.
