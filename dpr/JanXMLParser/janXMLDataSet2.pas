unit janXMLDataSet2;

interface

uses
  SysUtils, Controls,Classes, Db, BaseDataSet,janXMLParser2, janstrings;

const
  MaxFields= 255;

type
  TjanXMLDataSet2 = class(TGXBaseDataset)
  private
    FDom:TjanXMLParser2;
    xrows:TjanXMLNode2;
    xrow:TjanXMLNode2;
    xfields:TjanXMLNode2;
    FCurRec: Integer;
    FXMLFile: string;
    FReadOnly: Boolean;
    procedure SetXMLFile(const Value: string);
    procedure SetReadOnly(const Value: Boolean);
  protected {Simplified Dataset methods}
    function DoOpen: Boolean; override;
    procedure DoClose; override;
    procedure DoDeleteRecord; override;
    procedure DoCreateFieldDefs; override;
    function GetFieldValue(Field: TField): Variant; override;
    procedure SetFieldValue(Field: TField; Value: Variant); override;
    procedure GetBlobField(Field: TField; Stream: TStream); override;
    procedure SetBlobField(Field: TField; Stream: TStream); override;
    procedure DoFirst; override;
    procedure DoLast; override;
    function Navigate(GetMode: TGetMode): TGetResult; override;
    //Record ID functions
    function AllocateRecordID: Pointer; override;
    procedure DisposeRecordID(Value: Pointer); override;
    procedure GotoRecordID(Value: Pointer); override;
    //Bookmark functions
    function GetBookMarkSize: Integer; override;
    procedure AllocateBookMark(RecordID: Pointer; Bookmark: Pointer); override;
    procedure DoGotoBookmark(Bookmark: Pointer); override;
    //Others
    procedure DoBeforeGetFieldValue; override;
    procedure DoAfterGetFieldValue; override;
    procedure DoBeforeSetFieldValue(Inserting: Boolean); override;
    procedure DoAfterSetFieldValue(Inserting: Boolean); override;
  protected {Overriden datatset methods}
    function GetCanModify: Boolean; override;
    function GetRecordCount: Integer; override;
    function GetRecNo: Integer; override;
    procedure SetRecNo(Value: Integer); override;
  public
    constructor Create(AOwner:TComponent);override;
    destructor Destroy; override;
    procedure AddField(FieldName:string;Fieldtype:TFieldType;FieldSize:integer);
    function DeleteField(FieldName:string):boolean;
    function ChangeField(oldFieldName,newFieldName:string;newFieldType:TFieldType;newFieldSize:integer):boolean;
    function Save:boolean;
    class function StringToFieldType(pValue:string):TFieldType;
    class function FieldTypeToString(pValue:TFieldType):string;
    class function checkFloat(pValue:string):extended;
    class function checkDate(pValue:string):TDate;
    class function checkDateTime(pValue:string):TDateTime;
    property XMLDom:TjanXMLParser2 read FDom;
  published
    property XMLFile:string read FXMLFile write SetXMLFile;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly;
  end;

procedure Register;

implementation

uses
  TypInfo, Dialogs, Windows, Forms;

procedure Register;
begin
  RegisterComponents('JanSoft', [TjanXMLDataSet2]);
end;

procedure TjanXMLDataSet2.AddField(FieldName: string;Fieldtype:TFieldType;FieldSize: integer);
var
  xn:TjanXMLNode2;
begin
  xn:=TjanXMLNode2.create;
  xn.name:=FieldName;
  xn.attribute['size']:=inttostr(FieldSize);
  xn.attribute['type']:=FieldTypeToString(FieldType);
  xfields.addNode(xn);
  close;
  open;
end;

procedure TjanXMLDataSet2.AllocateBookMark(RecordID, Bookmark: Pointer);
begin
  PInteger(Bookmark)^:=Integer(RecordID);
end;

function TjanXMLDataSet2.AllocateRecordID: Pointer;
begin
  Result:=Pointer(FCurRec);
end;

constructor TjanXMLDataSet2.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Fdom:=TjanXMLParser2.create;
end;

function TjanXMLDataSet2.DeleteField(FieldName: string): boolean;
var
  xn:TjanXMLNode2;
begin
  result:=false;
  if xfields=nil then exit;
  xn:=xfields.getChildByName(FieldName);
  if xn=nil then exit;
  xfields.deleteNode(xn);
  close;
  open;
end;

destructor TjanXMLDataSet2.Destroy;
begin
  Fdom.free;
  inherited;
end;

procedure TjanXMLDataSet2.DisposeRecordID(Value: Pointer);
begin
  //Do nothing, no need to dispose since pointer is just an integer
end;

procedure TjanXMLDataSet2.DoAfterGetFieldValue;
begin
  if not ((xrow<>nil) and (State=dsInsert)) then
    xrow:=nil;
end;

procedure TjanXMLDataSet2.DoAfterSetFieldValue(Inserting: Boolean);
var Index: Integer;
begin
  if Inserting then Begin
    Index:=xrows.nodes.IndexOf(xrow);
    if Index>=1 then FCurRec:=Index-1;
  End;
  xrow:=nil;
end;

procedure TjanXMLDataSet2.DoBeforeGetFieldValue;
begin
  xrow:=TjanXMLNode2(xrows.nodes[FCurRec]);
end;

procedure TjanXMLDataSet2.DoBeforeSetFieldValue(Inserting: Boolean);
var
  xn:TjanXMLNode2;
begin
  if Inserting then begin
    xrow:=TjanXMLNode2.create;
    xrow.name:='row';
    xrows.addNode(xrow);
  end
  else xrow:=TjanXMLNode2(xrows.nodes[FCurRec]);
end;

procedure TjanXMLDataSet2.DoClose;
begin
  if fileexists(FXMLFile) then
    Fdom.SaveXML(FXMLFile);
  FieldDefs.Clear;
  FXMLFile:='';
end;

procedure TjanXMLDataSet2.DoCreateFieldDefs;
var
  i,c:integer;
  xfield:TjanXMLNode2;
  fielddef:TFieldDef;
  fieldsize:integer;
  fieldtype:TFieldType;

begin
  c:=xfields.nodes.count;
  if c>0 then
    for i:=0 to c-1 do begin
      xfield:=TjanXMLNode2(xfields.nodes[i]);
      fieldsize:=strtointdef(xfield.attribute['size'],30);
      fieldtype:=StringToFieldType(xfield.attribute['type']);
      FieldDef:=FieldDefs.AddFieldDef;
      FieldDef.Name:=xfield.name;
      FieldDef.DataType:=fieldtype;
      if fieldtype=ftString then
        fielddef.Size:=fieldsize;
      FieldDef.Required:=false;
    end;
end;

procedure TjanXMLDataSet2.DoDeleteRecord;
var
  xn:TjanXMLNode2;
begin
  xn:=TjanXMLNode2(xrows.nodes[RecNo-1]);
  xn.Free;
  xrows.nodes.Delete(recNo-1);
end;

procedure TjanXMLDataSet2.DoFirst;
begin
  FCurRec:=-1;
end;

procedure TjanXMLDataSet2.DoGotoBookmark(Bookmark: Pointer);
begin
  GotoRecordID(Pointer(PInteger(Bookmark)^));
end;

procedure TjanXMLDataSet2.DoLast;
begin
  FCurRec:=RecordCount;
end;

function TjanXMLDataSet2.DoOpen: Boolean;
begin
  FCurRec:=-1;
  Result:=xfields<>nil;
end;


class function TjanXMLDataSet2.FieldTypeToString(
  pValue: TFieldType): string;
begin
  case pValue of
    ftstring: result:='string';
    ftmemo: result:='memo';
    ftboolean: result:='boolean';
    ftinteger: result:='integer';
    ftfloat: result:='float';
    ftdate: result:='date';
    ftdatetime: result:='datetime';
    else result:='string';
  end;
end;

function TjanXMLDataSet2.GetBookMarkSize: Integer;
begin
  Result:=sizeof(Integer);
end;

function TjanXMLDataSet2.GetCanModify: Boolean;
begin
  Result:=not FReadOnly;
end;

function TjanXMLDataSet2.GetFieldValue(Field: TField): Variant;
var
  xn:TjanXMLNode2;
  tmp:string;
begin
  if xrow=nil then exit;
  xn:=xrow.getChildByName(Field.FieldName);
  if xn=nil then
    tmp:=''
  else
    tmp:=xn.text;
  case Field.DataType of
    ftstring: result:=tmp;
    ftmemo: result:=tmp;
    ftboolean: result:= (tmp='1');
    ftinteger:result:=strtointdef(tmp,0);
    ftfloat:result:=checkFloat(tmp);
    ftdate:result:=checkDate(tmp);
    ftdatetime:result:=checkDateTime(tmp);
    else result:=tmp;
  end
end;

function TjanXMLDataSet2.GetRecNo: Integer;
begin
  UpdateCursorPos;
  if (FCurRec=-1) and (RecordCount>0) then
    Result := 1 else
    Result := FCurRec + 1;
end;

function TjanXMLDataSet2.GetRecordCount: Integer;
begin
  Result:=xrows.nodes.Count;
end;

procedure TjanXMLDataSet2.GotoRecordID(Value: Pointer);
begin
  FCurRec:=Integer(Value);
end;

function TjanXMLDataSet2.Navigate(GetMode: TGetMode): TGetResult;
begin
  if RecordCount<1 then
    Result := grEOF
  else
    begin
    Result:=grOK;
    case GetMode of
      gmNext:
        Begin
        if FCurRec>=RecordCount-1 then Result:=grEOF
        else Inc(FCurRec);
        End;
      gmPrior:
        Begin
        if FCurRec<=0 then
          Begin
          Result:=grBOF;
          FCurRec:=-1;
          End
        else Dec(FCurRec);
        End;
      gmCurrent:
        if (FCurRec < 0) or (FCurRec >= RecordCount) then
          Result := grError;
    End;
    End;
end;


function TjanXMLDataSet2.ChangeField(oldFieldName,newFieldName:string;newFieldType:TFieldType;newFieldSize:integer):boolean;
var
  xn,xr:TjanXMLNode2;
  i,c:integer;
  oldFieldType:TFieldType;

  function CheckFloat(pValue:string):extended;
  begin
    try
      result:=strtofloat(pValue)
    except
      result:=0;
    end;
  end;

  function ValidateText(pValue:string):string;
  begin
    case newFieldType of
      ftstring,ftmemo:
        begin
          case oldFieldType of
            ftdate: result:=datetostr(checkdate(pValue));
            ftdatetime: result:=datetimetostr(checkdatetime(pValue));
          else result:=pValue;
          end;
        end;
      ftinteger: result:= inttostr(strtointdef(pValue,0));
      ftfloat: result:=floattostr(checkfloat(pValue));
      ftdate: result:= datetostr(checkdate(pValue));
      ftdatetime: result:=datetostr(checkdatetime(pValue));
      ftboolean:
        begin
          if pValue<>'0' then
            result:='1'
          else
            result:='0';  
        end;
      else result:=pValue;
    end;
  end;
begin
  result:=false;
  if xfields=nil then exit;
  xn:=xfields.getChildByName(oldFieldName);
  if xn=nil then exit;
  oldFieldType:=StringToFieldType(xn.attribute['type']);
  xn.name:=newFieldName;
  xn.attribute['type']:=FieldTypeToString(newFieldType);
  xn.attribute['size']:=inttostr(newFieldSize);
  c:=xrows.nodes.count;
  if c>0 then
    for i:=0 to c-1 do begin
      xr:=TjanXMLNode2(xrows.nodes[i]);
      xn:=xr.getChildByName(oldFieldName);
      if xn<>nil then begin
        xn.name:=newFieldName;
        xn.text:=ValidateText(xn.text);
      end;
    end;
  close;
  open;
  result:=true;
end;

procedure TjanXMLDataSet2.SetFieldValue(Field: TField; Value: Variant);
var
  tmp:string;
begin
  tmp:=value;
  if xrow<>nil then begin
    case Field.DataType of
      ftstring: tmp:=value;
      ftmemo: tmp:=value;
      ftboolean:
        begin
          if value then
            tmp:='1'
          else
            tmp:='0';  
        end;
      ftinteger: tmp:=inttostr(value);
      ftfloat: tmp:=floattostr(value);
      ftdate:
        begin
          tmp:= formatdatetime('yyyy-mm-dd',value);
        end;
      ftdatetime: tmp:=formatdatetime('yyyy-mm-dd',value);
      else tmp:=value;
    end;
    xrow.forceChildByName(Field.Fieldname).text:=tmp;
  end;
end;

procedure TjanXMLDataSet2.SetReadOnly(const Value: Boolean);
begin
  FReadOnly := Value;
end;

procedure TjanXMLDataSet2.SetRecNo(Value: Integer);
begin
  if (Value>0) and (Value<RecordCount) then
  begin
    FCurRec:=Value-1;
    Resync([]);
  end;
end;

procedure TjanXMLDataSet2.SetXMLFile(const Value: string);
begin
  if Active then
    DatabaseError('Cannot change XMLFile of an active dataset');
  if value<>'' then
    if not fileexists(value) then
      DatabaseError('Invalid XMLFile path.');
  FXMLFile := Value;
  Fdom.LoadXML(FXMLFile);
  xfields:=Fdom.getChildByName('fields');
  xrows:=Fdom.getChildByName('rows');
end;

class function TjanXMLDataSet2.StringToFieldType(
  pValue: string): TFieldType;
begin
  if pValue='string' then result:=ftstring
  else if pValue='memo' then result:=ftmemo
  else if pvalue='boolean' then result:=ftboolean
  else if pvalue='integer' then result:=ftinteger
  else if pValue='float' then result:=ftfloat
  else if pValue='date' then result:=ftdate
  else if pValue='datetime' then result:=ftdatetime
  else result:=ftstring;
end;

class function TjanXMLDataSet2.checkDate(pValue: string): TDate;
var
 oldformat:string;
 oldseparator:char;
begin
  oldformat:=shortdateformat;
  oldseparator:=DateSeparator;
  DateSeparator:='-';
  shortdateformat:='yyyy-mm-dd';
  try
    result:=strtodate(pValue);
  except
    result:=0;
  end;
  DateSeparator:= oldseparator;
  shortdateformat:=oldformat;
end;

class function TjanXMLDataSet2.checkFloat(pValue: string): extended;
begin
  try
    result:=strtofloat(pValue);
  except
    result:=0;
  end;
end;

class function TjanXMLDataSet2.checkDateTime(pValue: string): TDateTime;
var
 oldformat:string;
 oldseparator:char;
begin
  oldformat:=shortdateformat;
  oldseparator:=DateSeparator;
  DateSeparator:='-';
  shortdateformat:='yyyy-mm-dd';
  try
    result:=strtodatetime(pValue);
  except
    result:=0;
  end;
  DateSeparator:= oldseparator;
  shortdateformat:=oldformat;
end;

procedure TjanXMLDataSet2.GetBlobField(Field: TField; Stream: TStream);
var
  xn:TjanXMLNode2;
  tmp:string;
begin
  if xrow=nil then exit;
  xn:=xrow.getChildByName(Field.FieldName);
  if xn=nil then
    tmp:=''
  else
    tmp:=xn.text;
  janstrings.StringToStream(tmp,Stream);
end;

procedure TjanXMLDataSet2.SetBlobField(Field: TField; Stream: TStream);
var
  tmp:string;
begin
  tmp:=janstrings.StreamToString(Stream);
  if xrow<>nil then begin
    xrow.forceChildByName(Field.Fieldname).text:=tmp;
  end;
end;

function TjanXMLDataSet2.Save: boolean;
begin
  result:=true;
  if fileexists(FXMLFile) then
    Fdom.SaveXML(FXMLFile)
  else
    result:=false;
end;

end.
