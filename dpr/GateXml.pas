unit GateXml;

interface

uses
  Vcl.Forms, Xml.XMLDoc;

type
  TGateXmlNode = class(TObject)
  private
    doc: TXmlDocument;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TGateXmlParser = class(TGateXmlNode)
  private
  public
  end;

var
  xmlForm: TForm;

implementation

uses
  System.SysUtils;

constructor TGateXmlNode.Create;
begin
  inherited;
  doc:=TXmlDocument.Create(xmlForm);
end;

destructor TGateXmlNode.Destroy;
begin
  FreeAndNil(doc);
  inherited;
end;

end.