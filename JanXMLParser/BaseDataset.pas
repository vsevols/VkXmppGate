unit BaseDataset;

interface

uses Classes, SysUtils, Windows, Forms, DB;

type
  PRecordInfo = ^TRecordInfo;
  TRecordInfo = record
    RecordID: Pointer;
    Bookmark: Pointer;
    BookMarkFlag: TBookmarkFlag;
  end;

  TGXBaseDataset = class(TDataset)
  private
    FisOpen: Boolean;
    FStartCalculated: Integer;
    FBufferMap: TStringList;
    procedure FillBufferMap;
    function _GetRecord(Buffer: PChar; GetMode: TGetMode;
      DoCheck: Boolean): TGetResult;
    function RecordFilter: Boolean;
  protected {My simplified methods to override}
    function DoOpen: Boolean; virtual; abstract;
    procedure DoClose; virtual; abstract;
    procedure DoDeleteRecord; virtual;
    procedure DoCreateFieldDefs; virtual; abstract;
    function GetFieldValue(Field: TField): Variant; virtual; abstract;
    procedure SetFieldValue(Field: TField; Value: Variant); virtual; abstract;
    procedure GetBlobField(Field: TField; Stream: TStream); virtual; abstract;
    procedure SetBlobField(Field: TField; Stream: TStream); virtual; abstract;
    //Called before and after getting a set of field values
    procedure DoBeforeGetFieldValue; virtual;
    procedure DoAfterGetFieldValue; virtual;
    procedure DoBeforeSetFieldValue(Inserting: Boolean); virtual;
    procedure DoAfterSetFieldValue(Inserting: Boolean); virtual;
    //Handle buffer ID
    function AllocateRecordID: Pointer; virtual; abstract;
    procedure DisposeRecordID(Value: Pointer); virtual; abstract;
    procedure GotoRecordID(Value: Pointer); virtual; abstract;
    //BookMark functions
    function GetBookMarkSize: Integer; virtual;
    procedure DoGotoBookmark(Bookmark: Pointer); virtual; abstract;
    procedure AllocateBookMark(RecordID: Pointer; Bookmark: Pointer); virtual; abstract;
    //Navigation methods
    procedure DoFirst; virtual; abstract;
    procedure DoLast; virtual; abstract;
    function Navigate(GetMode: TGetMode): TGetResult; virtual; abstract;
    procedure SetFiltered(Value: Boolean); override;
    //Internal isOpen property
    property isOpen: Boolean read FisOpen;
  protected {TGXBaseDataset Internal functions that can be overriden if needed}
    procedure AllocateBLOBPointers(Buffer: PChar); virtual;
    procedure FreeBlobPointers(Buffer: PChar); virtual;
    procedure FreeRecordPointers(Buffer: PChar); virtual;
    function GetDataSize: Integer; virtual;
    function GetFieldOffset(Field: TField): Integer; virtual;
    procedure BufferToRecord(Buffer: PChar); virtual;
    procedure RecordToBuffer(Buffer: PChar); virtual;
  protected
    function AllocRecordBuffer: PChar; override;
    procedure FreeRecordBuffer(var Buffer: PChar); override;
    function GetRecord(Buffer: PChar; GetMode: TGetMode; DoCheck: Boolean): TGetResult; override;
    function GetRecordSize: Word; override;
    procedure InternalInsert; override;
    procedure InternalClose; override;
    procedure InternalDelete; override;
    procedure InternalFirst; override;
    procedure InternalEdit; override;
    procedure InternalHandleException; override;
    procedure InternalInitFieldDefs; override;
    procedure InternalInitRecord(Buffer: PChar); override;
    procedure InternalLast; override;
    procedure InternalOpen; override;
    procedure InternalPost; override;
    procedure InternalSetToRecord(Buffer: PChar); override;
    procedure InternalAddRecord(Buffer: Pointer; Append: Boolean); override;
    function IsCursorOpen: Boolean; override;
    function GetCanModify: Boolean; override;
    procedure ClearCalcFields(Buffer: PChar); override;
    function GetActiveRecordBuffer: PChar; virtual;
    procedure SetFieldData(Field: TField; Buffer: Pointer); override;
    procedure GetBookmarkData(Buffer: PChar; Data: Pointer); override;
    function GetBookmarkFlag(Buffer: PChar): TBookmarkFlag; override;
    procedure SetBookmarkFlag(Buffer: PChar; Value: TBookmarkFlag); override;
    procedure SetBookmarkData(Buffer: PChar; Data: Pointer); override;
    procedure InternalGotoBookmark(Bookmark: Pointer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetFieldData(Field: TField; Buffer: Pointer): Boolean; override;
    function CreateBlobStream(Field: TField; Mode: TBlobStreamMode): TStream; override;
  end;

  TGXBlobStream = class(TMemoryStream)
  private
    FField: TBlobField;
    FDataSet: TGXBaseDataSet;
    FMode: TBlobStreamMode;
    FModified: Boolean;
    FOpened: Boolean;
    procedure LoadBlobData;
    procedure SaveBlobData;
  public
    constructor Create(Field: TBlobField; Mode: TBlobStreamMode);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

implementation

{ TGXBaseDataset }

constructor TGXBaseDataset.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBufferMap := TStringList.Create;
end;

destructor TGXBaseDataset.Destroy;
begin
  if Active then
    Close;
  FBufferMap.Free;
  inherited Destroy;
end;

procedure TGXBaseDataset.FillBufferMap;
var
  Index: Integer;
begin
  FBufferMap.Clear;
  for Index := 0 to FieldCount - 1 do
    FBufferMap.Add(Fields[Index].FieldName);
end;

procedure TGXBaseDataset.InternalOpen;
begin
  if DoOpen then
    begin
      BookmarkSize := GetBookMarkSize; //Bookmarks not supported
      InternalInitFieldDefs;
      if DefaultFields then
        CreateFields;
      BindFields(True);
      FisOpen := True;
      FillBufferMap;
    end;
end;

function TGXBaseDataset.AllocRecordBuffer: PChar;
begin
  GetMem(Result, GetRecordSize);
  FillChar(Result^, GetRecordSize, 0);
  AllocateBlobPointers(Result);
end;

procedure TGXBaseDataset.FreeRecordBuffer(var Buffer: PChar);
begin
  FreeRecordPointers(Buffer);
  FreeMem(Buffer, GetRecordSize);
end;

procedure TGXBaseDataset.FreeRecordPointers(Buffer: PChar);
begin
  FreeBlobPointers(Buffer);
  DisposeRecordID(PRecordInfo(Buffer + GetDataSize).RecordID);
  if PRecordInfo(Buffer + GetDataSize)^.BookMark <> nil then
    begin
      FreeMem(PRecordInfo(Buffer + GetDataSize)^.BookMark);
      PRecordInfo(Buffer + GetDataSize)^.BookMark := nil;
    end;
end;

procedure TGXBaseDataset.AllocateBLOBPointers(Buffer: PChar);
var
  Index: Integer;
  Offset: Integer;
  Stream: TMemoryStream;
begin
  for Index := 0 to FieldCount - 1 do
    if Fields[Index].DataType in [ftMemo, ftGraphic] then
      begin
        Offset := GetFieldOffset(Fields[Index]);
        Stream := TMemoryStream.Create;
        Move(Pointer(Stream), (Buffer + Offset)^, sizeof(Pointer));
      end;
end;

procedure TGXBaseDataset.FreeBlobPointers(Buffer: PChar);
var
  Index: Integer;
  Offset: Integer;
  FreeObject: TObject;
begin
  for Index := 0 to FieldCount - 1 do
    if Fields[Index].DataType in [ftMemo, ftGraphic] then
      begin
        Offset := GetFieldOffset(Fields[Index]);
        Move((Buffer + Offset)^, Pointer(FreeObject), sizeof(Pointer));
        if FreeObject <> nil then
          FreeObject.Free;
        FreeObject := nil;
        Move(Pointer(FreeObject), (Buffer + Offset)^, sizeof(Pointer));
      end;
end;

procedure TGXBaseDataset.InternalInitFieldDefs;
begin
  DoCreateFieldDefs;
end;

procedure TGXBaseDataset.ClearCalcFields(Buffer: PChar);
begin
  FillChar(Buffer[FStartCalculated], CalcFieldsSize, 0);
end;

function TGXBaseDataset.GetActiveRecordBuffer: PChar;
begin
  case State of
    dsBrowse: if isEmpty then
        Result := nil
      else
        Result := ActiveBuffer;
    dsCalcFields: Result := CalcBuffer;
    dsFilter: Result := TempBuffer;
    dsEdit, dsInsert: Result := ActiveBuffer;
  else
    Result := nil;
  end;
end;

function TGXBaseDataset.GetCanModify: Boolean;
begin
  Result := False;
end;

function TGXBaseDataset.RecordFilter: Boolean;
var
  SaveState: TDataSetState;
begin
  Result := True;
  if Assigned(OnFilterRecord) then
    begin
      SaveState := SetTempState(dsFilter);
      try
        RecordToBuffer(TempBuffer);
        OnFilterRecord(Self, Result);
      except
        Application.HandleException(Self);
      end;
      RestoreState(SaveState);
    end;
end;

function TGXBaseDataset.GetRecord(Buffer: PChar; GetMode: TGetMode; DoCheck: Boolean): TGetResult;
var
  localAccept : boolean;
begin
  localAccept := True;
  repeat
    Result := Navigate(GetMode);
    if (Result = grOk) then
      begin
        if Filtered then
          localAccept := RecordFilter;

        if localAccept then
          begin
            RecordToBuffer(Buffer);
            ClearCalcFields(Buffer);
            GetCalcFields(Buffer);
          end;
      end
    else if (Result = grError) and DoCheck then
      DatabaseError('No Records');
  until localAccept or (Result in [grEOF, grBOF]);
end;

function TGXBaseDataset._GetRecord(Buffer: PChar; GetMode: TGetMode; DoCheck: Boolean): TGetResult;
begin
  Result := Navigate(GetMode);
  if (Result = grOk) then
    begin
      RecordToBuffer(Buffer);
      ClearCalcFields(Buffer);
      GetCalcFields(Buffer);
    end
  else if (Result = grError) and DoCheck then
    DatabaseError('No Records');
end;

function TGXBaseDataset.GetRecordSize: Word;
begin
  Result := GetDataSize + sizeof(TRecordInfo) + CalcFieldsSize;
  FStartCalculated := GetDataSize + sizeof(TRecordInfo);
end;

function TGXBaseDataset.GetDataSize: Integer;
var
  Index: Integer;
begin
  Result := 0;
  for Index := 0 to FieldCount - 1 do
    case Fields[Index].DataType of
      ftString: Result := Result + Fields[Index].Size + 1; //Leave space for terminating null
      ftInteger, ftSmallInt, ftDate, ftTime: Result := Result + sizeof(Integer);
      ftFloat, ftCurrency, ftBCD, ftDateTime: Result := Result + sizeof(Double);
      ftBoolean: Result := Result + sizeof(WordBool);
      ftMemo, ftGraphic: Result := Result + sizeof(Pointer);
    end;
end;

procedure TGXBaseDataset.InternalClose;
begin
  BindFields(False);
  if DefaultFields then
    DestroyFields;
  DoClose;
  FisOpen := False;
end;

procedure TGXBaseDataset.InternalDelete;
begin
  DoDeleteRecord;
end;

procedure TGXBaseDataset.InternalEdit;
begin
  if GetActiveRecordBuffer <> nil then
    InternalSetToRecord(GetActiveRecordBuffer);
end;

procedure TGXBaseDataset.InternalFirst;
begin
  DoFirst;
end;

procedure TGXBaseDataset.InternalHandleException;
begin
  Application.HandleException(Self);
end;

{This is called by the TDataset to initialize an already existing buffer.
We cannot just fill the buffer with 0s since that would overwrite our BLOB pointers.
Therefore we free the blob pointers first, then fill the buffer with zeros, then
reallocate the blob pointers}

procedure TGXBaseDataset.InternalInitRecord(Buffer: PChar);
begin
  FreeRecordPointers(Buffer);
  FillChar(Buffer^, GetRecordSize, 0);
  AllocateBlobPointers(Buffer);
end;

procedure TGXBaseDataset.InternalInsert;
begin

end;

procedure TGXBaseDataset.InternalLast;
begin
  DoLast;
end;

procedure TGXBaseDataset.InternalPost;
begin
  if FisOpen then
    begin
      DoBeforeSetFieldValue(State = dsInsert);
      BufferToRecord(GetActiveRecordBuffer);
      DoAfterSetFieldValue(State = dsInsert);
    end;
end;

procedure TGXBaseDataset.InternalAddRecord(Buffer: Pointer; Append: Boolean);
begin
  if Append then
    InternalLast;
  DoBeforeSetFieldValue(True);
  BufferToRecord(Buffer);
  DoAfterSetFieldValue(True);
end;

procedure TGXBaseDataset.InternalSetToRecord(Buffer: PChar);
begin
  GotoRecordID(PRecordInfo(Buffer + GetDataSize).RecordID);
end;

function TGXBaseDataset.IsCursorOpen: Boolean;
begin
  Result := FisOpen;
end;

function TGXBaseDataset.GetFieldOffset(Field: TField): Integer;
var
  Index, FPos: Integer;
begin
  Result := 0;
  FPos := FBufferMap.Indexof(Field.FieldName);
  for Index := 0 to FPos - 1 do
    begin
      case FieldbyName(FBufferMap[Index]).DataType of
        ftString: inc(Result, FieldbyName(FBufferMap[Index]).Size + 1);
        ftInteger, ftSmallInt, ftDate, ftTime: inc(Result, sizeof(Integer));
        ftDateTime, ftFloat, ftBCD, ftCurrency: inc(Result, sizeof(Double));
        ftBoolean: inc(Result, sizeof(WordBool));
        ftGraphic, ftMemo: inc(Result, sizeof(Pointer));
      end;
    end;
end;

procedure TGXBaseDataset.BufferToRecord(Buffer: PChar);
var
  TempStr: string;
  TempInt: Integer;
  TempDouble: Double;
  TempBool: WordBool;
  Offset: Integer;
  Index: Integer;
  Stream: TStream;
begin
  for Index := 0 to FieldCount - 1 do
    begin
      Offset := GetFieldOffset(Fields[Index]);
      case Fields[Index].DataType of
        ftString:
          begin
            TempStr := PChar(Buffer + Offset);
            SetFieldValue(Fields[Index], TempStr);
          end;
        ftInteger, ftSmallInt, ftDate, ftTime:
          begin
            Move((Buffer + Offset)^, TempInt, sizeof(Integer));
            SetFieldValue(Fields[Index], TempInt);
          end;
        ftFloat, ftBCD, ftCurrency, ftDateTime:
          begin
            Move((Buffer + Offset)^, TempDouble, sizeof(Double));
            SetFieldValue(Fields[Index], TempDouble);
          end;
        ftBoolean:
          begin
            Move((Buffer + Offset)^, TempBool, sizeof(WordBool));
            SetFieldValue(Fields[Index], TempBool);
          end;
        ftGraphic, ftMemo:
          begin
            Move((Buffer + Offset)^, Pointer(Stream), sizeof(Pointer));
            Stream.Position := 0;
            SetBlobField(Fields[Index], Stream);
          end;
      end;
    end;
end;

procedure TGXBaseDataset.RecordToBuffer(Buffer: PChar);
var
  Value: Variant;
  TempStr: string;
  TempInt: Integer;
  TempDouble: Double;
  TempBool: WordBool;
  Offset: Integer;
  Index: Integer;
  Stream: TStream;
begin
  with PRecordInfo(Buffer + GetDataSize)^ do
    begin
      BookmarkFlag := bfCurrent;
      RecordID := AllocateRecordID;
      if GetBookMarkSize > 0 then
        begin
          if BookMark = nil then
            GetMem(BookMark, GetBookMarkSize);
          AllocateBookMark(RecordID, BookMark);
        end
      else
        BookMark := nil;
    end;
  DoBeforeGetFieldValue;
  for Index := 0 to FieldCount - 1 do
    begin
      if not (Fields[Index].DataType in [ftMemo, ftGraphic]) then
        Value := GetFieldValue(Fields[Index]);
      Offset := GetFieldOffset(Fields[Index]);
      case Fields[Index].DataType of
        ftString:
          begin
            TempStr := Value;
            if length(TempStr) > Fields[Index].Size then
              System.Delete(TempStr, Fields[Index].Size, length(TempStr) - Fields[Index].Size);
            StrLCopy(PChar(Buffer + Offset), PChar(TempStr), length(TempStr));
          end;
        ftInteger, ftSmallInt, ftDate, ftTime:
          begin
            TempInt := Value;
            Move(TempInt, (Buffer + Offset)^, sizeof(TempInt));
          end;
        ftFloat, ftBCD, ftCurrency, ftDateTime:
          begin
            TempDouble := Value;
            Move(TempDouble, (Buffer + Offset)^, sizeof(TempDouble));
          end;
        ftBoolean:
          begin
            TempBool := Value;
            Move(TempBool, (Buffer + Offset)^, sizeof(TempBool));
          end;
        ftMemo, ftGraphic:
          begin
            Move((Buffer + Offset)^, Pointer(Stream), sizeof(Pointer));
            Stream.Size := 0;
            Stream.Position := 0;
            GetBlobField(Fields[Index], Stream);
          end;
      end;
    end;
  DoAfterGetFieldValue;
end;

procedure TGXBaseDataset.DoDeleteRecord;
begin
  //Nothing in base class
end;

function TGXBaseDataset.GetFieldData(Field: TField; Buffer: Pointer): Boolean;
var
  RecBuffer: PChar;
  Offset: Integer;
  TempDouble: Double;
  Data: TDateTimeRec;
  TimeStamp: TTimeStamp;
  TempBool: WordBool;
begin
  Result := false;
  if not FisOpen then
    exit;
  RecBuffer := GetActiveRecordBuffer;
  if RecBuffer = nil then
    exit;
  if Buffer = nil then
    begin
    //Dataset checks if field is null by passing a nil buffer
    //Tell it is not null by passing back a result of True
      Result := True;
      exit;
    end;
  if (Field.FieldKind = fkCalculated) or (Field.FieldKind = fkLookup) then
    begin
      inc(RecBuffer, FStartCalculated + Field.Offset);
      if (RecBuffer[0] = #0) or (Buffer = nil) then
        exit
      else
        CopyMemory(Buffer, @RecBuffer[1], Field.DataSize);
    end
  else
    begin
      Offset := GetFieldOffset(Field);
      case Field.DataType of
        ftInteger, ftTime, ftDate: Move((RecBuffer + Offset)^, Integer(Buffer^), sizeof(Integer));
        ftBoolean:
          begin
            Move((RecBuffer + Offset)^, TempBool, sizeof(WordBool));
            Move(TempBool, WordBool(Buffer^), sizeof(WordBool));
          end;
        ftString: StrLCopy(Buffer, PChar(RecBuffer + Offset), StrLen(PChar(RecBuffer + Offset)));
        ftCurrency, ftFloat: Move((RecBuffer + Offset)^, Double(Buffer^), sizeof(Double));
        ftDateTime:
          begin
            Move((RecBuffer + Offset)^, TempDouble, sizeof(Double));
            TimeStamp := DateTimeToTimeStamp(TempDouble);
            Data.DateTime := TimeStampToMSecs(TimeStamp);
            Move(Data, Buffer^, sizeof(TDateTimeRec));
          end;
      end;
    end;
  Result := True;
end;

procedure TGXBaseDataset.SetFieldData(Field: TField; Buffer: Pointer);
var
  Offset: Integer;
  RecBuffer: Pchar;
  TempDouble: Double;
  Data: TDateTimeRec;
  TimeStamp: TTimeStamp;
  TempBool: WordBool;
begin
  if not Active then
    exit;
  RecBuffer := GetActiveRecordBuffer;
  if RecBuffer = nil then
    exit;
  if Buffer = nil then
    exit;
  if (Field.FieldKind = fkCalculated) or (Field.FieldKind = fkLookup) then
    begin
      Inc(RecBuffer, FStartCalculated + Field.Offset);
      Boolean(RecBuffer[0]) := (Buffer <> nil);
      if Boolean(RecBuffer[0]) then
        CopyMemory(@RecBuffer[1], Buffer, Field.DataSize);
    end
  else
    begin
      Offset := GetFieldOffset(Field);
      case Field.DataType of
        ftInteger, ftDate, ftTime: Move(Integer(Buffer^), (RecBuffer + Offset)^, sizeof(Integer));
        ftBoolean:
          begin
            Move(WordBool(Buffer^), TempBool, sizeof(WordBool));
            Move(TempBool, (RecBuffer + Offset)^, sizeof(WordBool));
          end;
        ftString: StrLCopy(PChar(RecBuffer + Offset), Buffer, StrLen(PChar(Buffer)));
        ftDateTime:
          begin
            Data := TDateTimeRec(Buffer^);
            TimeStamp := MSecsToTimeStamp(Data.DateTime);
            TempDouble := TimeStampToDateTime(TimeStamp);
            Move(TempDouble, (RecBuffer + Offset)^, sizeof(TempDouble));
          end;
        ftFloat, ftCurrency: Move(Double(Buffer^), (RecBuffer + Offset)^, sizeof(Double));
      end;
    end;
  if not (State in [dsCalcFields, dsFilter, dsNewValue]) then
    DataEvent(deFieldChange, Longint(Field));
end;

function TGXBaseDataset.GetBookMarkSize: Integer;
begin
  Result := 0;
end;

procedure TGXBaseDataset.GetBookmarkData(Buffer: PChar; Data: Pointer);
begin
  if BookMarkSize > 0 then
    AllocateBookMark(PRecordInfo(Buffer + GetDataSize).RecordID, Data);
end;

function TGXBaseDataset.GetBookmarkFlag(Buffer: PChar): TBookmarkFlag;
begin
  Result := PRecordInfo(Buffer + GetDataSize).BookMarkFlag;
end;

procedure TGXBaseDataset.SetBookmarkData(Buffer: PChar; Data: Pointer);
begin
  if PRecordInfo(Buffer + GetDataSize)^.BookMark = nil then
    GetMem(PRecordInfo(Buffer + GetDataSize)^.BookMark, GetBookMarkSize);
  Move(PRecordInfo(Buffer + GetDataSize).BookMark^, Data, GetBookMarkSize);
end;

procedure TGXBaseDataset.SetBookmarkFlag(Buffer: PChar; Value: TBookmarkFlag);
begin
  PRecordInfo(Buffer + GetDataSize).BookMarkFlag := Value;
end;

procedure TGXBaseDataset.InternalGotoBookmark(Bookmark: Pointer);
begin
  DoGotoBookMark(BookMark);
end;

function TGXBaseDataSet.CreateBlobStream(Field: TField; Mode: TBlobStreamMode): TStream;
begin
  Result := TGXBlobStream.Create(Field as TBlobField, Mode);
end;

procedure TGXBaseDataset.DoAfterGetFieldValue;
begin

end;

procedure TGXBaseDataset.DoBeforeGetFieldValue;
begin

end;

procedure TGXBaseDataset.DoAfterSetFieldValue(Inserting: Boolean);
begin

end;

procedure TGXBaseDataset.DoBeforeSetFieldValue(Inserting: Boolean);
begin

end;

//************************** TOBlobStream ***************************************

constructor TGXBlobStream.Create(Field: TBlobField; Mode: TBlobStreamMode);
begin
  inherited Create;
  FField := Field;
  FMode := Mode;
  FDataSet := FField.DataSet as TGXBaseDataset;
  if Mode <> bmWrite then
    LoadBlobData;
end;

destructor TGXBlobStream.Destroy;
begin
  if FModified then
    SaveBlobData;
  inherited Destroy;
end;

function TGXBlobStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := inherited Read(Buffer, Count);
  FOpened := True;
end;

function TGXBlobStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := inherited Write(Buffer, Count);
  FModified := True;
end;

procedure TGXBlobStream.LoadBlobData;
var
  Stream: TMemoryStream;
  Offset: Integer;
  RecBuffer: PChar;
begin
  Self.Size := 0;
  RecBuffer := FDataset.GetActiveRecordBuffer;
  if RecBuffer <> nil then
    begin
      Offset := FDataset.GetFieldOffset(FField);
      Move((RecBuffer + Offset)^, Pointer(Stream), sizeof(Pointer));
      Self.CopyFrom(Stream, 0);
    end;
  Position := 0;
end;

procedure TGXBlobStream.SaveBlobData;
var
  Stream: TMemoryStream;
  Offset: Integer;
  RecBuffer: Pchar;
begin
  RecBuffer := FDataset.GetActiveRecordBuffer;
  if RecBuffer <> nil then
    begin
      Offset := FDataset.GetFieldOffset(FField);
      Move((RecBuffer + Offset)^, Pointer(Stream), sizeof(Pointer));
      Stream.Size := 0;
      Stream.CopyFrom(Self, 0);
      Stream.Position := 0;
    end;
  FModified := False;
end;

procedure TGXBaseDataset.SetFiltered(Value: Boolean);
begin
  inherited;
  First;
end;

end.

