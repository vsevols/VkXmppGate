unit GateXml;

interface



uses
  Vcl.Forms, System.Classes, NativeXml;

type
  TGateXmlNode = class(TComponent)
  private
    doc: TNativeXml;
    FNode: TXMLNode;
    function Getattribute(name:string): Variant;
    function GetchildCount: Integer;
    function GetchildNode(Index: Integer): TGateXmlNode;
    function GetFirstChild: TGateXmlNode;
    function Getname: string;
    function GetNextSibling: TGateXmlNode;
    function GetparentNode: TGateXmlNode;
    function Gettext: string;
  public
    constructor Create(AOwner: TComponent; ANode: TXMLNode);
    destructor Destroy; override;
    function getChildByName(name: string): TGateXmlNode;
    property attribute[name:string]: Variant read Getattribute;
    property childCount: Integer read GetchildCount;
    property childNode[Index: Integer]: TGateXmlNode read GetchildNode;
    property FirstChild: TGateXmlNode read GetFirstChild;
    property name: string read Getname;
    property NextSibling: TGateXmlNode read GetNextSibling;
    property parentNode: TGateXmlNode read GetparentNode;
    property text: string read Gettext;
  end;

  TGateXmlParser = class(TGateXmlNode)
  private
    function GetrootNode: TGateXmlNode;
    function Getxml: string;
    procedure Setxml(const Value: string);
  public
    constructor Create;
    destructor Destroy; override;
    property rootNode: TGateXmlNode read GetrootNode;
    property xml: string read Getxml write Setxml;
  end;

//var
  //xmlForm: TForm;
  //iNodes, iPars:integer;

implementation

uses
  System.SysUtils, ActiveX;

constructor TGateXmlNode.Create(AOwner: TComponent; ANode: TXMLNode);
begin
  inherited Create(AOwner);
  FNode:=ANode;
end;

destructor TGateXmlNode.Destroy;
begin
  FNode:=nil;
  inherited;
end;

function TGateXmlNode.Getattribute(name:string): Variant;
begin
  Result := FNode.AttributeValueByName[name];
end;

function TGateXmlNode.getChildByName(name: string): TGateXmlNode;
var
  node: TXMLNode;
begin
  Result:=nil;
  node:=FNode.NodeByName(name);
  if Assigned(node) then
    Result:=TGateXmlNode.Create(Self, node);
end;

function TGateXmlNode.GetchildCount: Integer;
begin
  Result := FNode.ElementCount;
end;

function TGateXmlNode.GetchildNode(Index: Integer): TGateXmlNode;
begin
  Result:=TGateXmlNode.Create(Self, FNode.Elements[Index]);
end;

function TGateXmlNode.GetFirstChild: TGateXmlNode;
begin
  Result:=nil;
  if Assigned(FNode) and (FNode.ElementCount>0) then
    Result := GetchildNode(0);
end;

function TGateXmlNode.Getname: string;
begin
  Result := FNode.Name;
end;

function TGateXmlNode.GetNextSibling: TGateXmlNode;
var
  sib: TXmlNode;
begin
  Result:=nil;
  sib:=nil;
  try
    sib:=FNode.NextSibling(FNode);
  except
   // 'index must be >= 0' can be raised
  end;

  if Assigned(sib) then
    Result := TGateXmlNode.Create(Self, sib);
end;

function TGateXmlNode.GetparentNode: TGateXmlNode;
begin
  Result := TGateXmlNode.Create(Self, FNode.Parent);
end;

function TGateXmlNode.Gettext: string;
begin
  Result := FNode.Value;
end;

constructor TGateXmlParser.Create;
begin
  //CoInitialize(nil);
  doc:=TNativeXml.Create(Self);
  inherited Create(nil, nil);
end;

destructor TGateXmlParser.Destroy;
begin
  doc.Free;
  //doc:=nil;
  inherited;
  //CoUnInitialize();
end;

function TGateXmlParser.GetrootNode: TGateXmlNode;
begin
  if Assigned(doc.Root) then
    Result:=TGateXmlNode.Create(Self, doc.Root)
    else Result:=nil;
end;

function TGateXmlParser.Getxml: string;
begin
  Result := doc.WriteToString;
end;

procedure TGateXmlParser.Setxml(const Value: string);
begin
  doc.ReadFromString(Value);
  FNode:=doc.Root;
end;

end.
