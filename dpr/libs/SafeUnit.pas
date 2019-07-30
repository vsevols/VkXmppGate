unit SafeUnit;

// Является ремейком модуля "SafeUnit" неизвестного мне автора.

interface

uses Classes;

/////////////////////////////////////////////////////////////////////////// IsAs
(*
Позволяет упростить вот такие фрагметы кода:

  if aSomeObject is TMyObject then begin
    aMyObject := aSomeObject as TMyObject;
    // некоторые действия с aMyObject
  end;

При использовании функции IsAs это будет выглядить так:

  if IsAs (aMyObject, aSomeObject, TMyObject) then begin
    ... // некоторые действия с aMyObject
  end;

*)

function IsAs(out aReference; const aObject: TObject; const aClass: TClass;
    aAssert: Boolean = False): Boolean;

////////////////////////////////////////////////////////////////// ExceptionSafe
(* - "Накопитель" исключений
Позволяет делать например следующее

    with ExceptionSafe do
      try
        // Некоторые действия которые могут возбудить исключение
        for aIndex := 1 to 10 do
          try
            ... // Некоторые действия которые могут возбудить исключение
          except
            SaveException;  // <- запоминание текста возникшего исключения в списке ExceptionSafe
          end;
        ... // Некоторые действия которые могут возбудить исключение
        for aIndex := 10 to 20 do
          try
            ... // Некоторые действия которые могут возбудить исключение
          except
            SaveException;  // <- запоминание текста возникшего исключения в списке ExceptionSafe
          end;
        ... // Некоторые действия которые могут возбудить исключение
      except
        SaveException;  // <- запоминание текста возникшего исключения в списке ExceptionSafe
      end;
    end;// <===

  Тогда, в момент выхода из With (<===), если был сохранен текст хотя бы
  одного исключения, будет возбуждено Exception, с текстом всех сохраненных
  в этом блоке исключений.
  Формат текста:
    Ex1.ClassName+': '+Ex1.Message  {+^M^J^I+ExN.ClassName+' '+ExN.Message}
*)

type
  IExceptionSafe = interface
    procedure SaveException;
  end;

function ExceptionSafe :IExceptionSafe;

///////////////////////////////////////////////////////////////////// ObjectSafe
(* - Безопасный "контейнер" объектов и компонентов

Пример использования:

  procedure TestTheSafe;
  var
    aMyObject    :TMyObject;
    aMyComponent :TMyComponent;
  begin
    with ObjectSafe do begin

      // создание и регистрация объекта:
      New (aMyObject, TMyObject.Create);
      // или
      aMyObject := TMyObject.Create; Guard(aMyObject);

      // создание и регистрация компонента
      aMyComponent := TMyComponent.Create (Safe);

      ... // Некоторые действия которые могут возбудить исключение

      // уничтожение экземпляра aMyObject
      Dispose(aMyObject);

      ... // Некоторые действия которые могут возбудить исключение

    end; // <===
  end;

  Тогда, в момент выхода из With (<===), все объекты и компоненты
  зарегестрированные в ObjectSafe, будут автоматически уничтожены (Free).
  Причем, это произойжет даже если With будет покинут в результате
  возникновения исключительной ситуации.

  При уничтожении, сначала в произвольном порядке будут уничтожены
  зарегестрированные объекты, а затем, будут уничтожены
  зарегестрированные компоненты, так же в произвольном порядке.
*)

type
  IObjectSafe = interface
    function  Safe : TComponent;

    function  New     (out   aReference {: Pointer};
                       const aObject     : TObject) : IObjectSafe;

    procedure Guard   (const aObject     : TObject);

    procedure Dispose (var   aReference {: Pointer});
  end;

function ObjectSafe                                 : IObjectSafe; overload;
function ObjectSafe (out aObjectSafe : IObjectSafe) : IObjectSafe; overload;

procedure SafeFreeAndNil(var AObject);

procedure FreeStringListObjects(var ASl: TStringList);


////////////////////////////////////////////////////////////////////////////////


implementation /////////////////////////////////////////////////////////////////

uses Windows, SysUtils;

/////////////////////////////////////////////////////////////////////////// IsAs

function IsAs(out aReference; const aObject: TObject; const aClass: TClass;
    aAssert: Boolean = False): Boolean;
begin
 Result := (aObject <> Nil) and (aObject is aClass);

 if   Result
 then TObject (aReference) := aObject;

 if aAssert then
  if Assigned(aObject) then
  Assert(Result, aObject.ClassName+'<>'+aClass.ClassName)
  else
    Assert(Result, 'nil<>'+aClass.ClassName);
end;

///////////////////////////////////////////////////////////////// TExceptionSafe

{ TExceptionSafe }

type
  TExceptionSafe = class (TInterfacedObject, IExceptionSafe)
    private
      FMessages : String;
    public
      destructor Destroy; override;

      procedure SaveException;
    end;

destructor TExceptionSafe.Destroy;
begin
  try
    if  FMessages <> ''  then
      raise Exception.Create(Copy(FMessages,4,MaxInt));
  finally
    try inherited Destroy; except end;
  end;
end;

procedure TExceptionSafe.SaveException;
begin
  try
    if  (ExceptObject <> Nil) and (ExceptObject is Exception)  then
      with Exception(ExceptObject) do
        FMessages := FMessages + ^M^J^I + ClassName + ': ' + Message;
  except
  end;
end;

{ ExceptionSafe }

function ExceptionSafe : IExceptionSafe;
begin
 Result := TExceptionSafe.Create;
end;

///////////////////////////////////////////////////////////////////// ObjectSafe

{ TInterfacedComponent }

type
  TInterfacedComponent = class (TComponent)
    private
      FRefCount : Integer;
    protected
      function _AddRef  : Integer; stdcall;
      function _Release : Integer; stdcall;
    public
      procedure BeforeDestruction; override;
   end;

function TInterfacedComponent._AddRef : Integer;
begin
 Result := InterlockedIncrement (FRefCount);
end;

function TInterfacedComponent._Release : Integer;
begin
 Result := InterlockedDecrement (FRefCount);
 if  Result = 0  then Destroy;
end;

procedure TInterfacedComponent.BeforeDestruction;
begin
 if  FRefCount <> 0  then
   raise Exception.Create (ClassName + ' not freed correctly');
end;

{ TObjectSafe }

type
  TAddObjectMethod = procedure (const aObject : TObject) of object;

  TObjectSafe = class (TInterfacedComponent, IObjectSafe)
    private
      FObjects    : array of TObject;
      FEmptySlots : array of Integer;
      AddObject   : TAddObjectMethod;

      procedure AddObjectAtEndOfList (const aObject : TObject);
      procedure AddObjectInEmptySlot (const aObject : TObject);

      procedure RemoveObject (const aObject : TObject);
    public
      constructor Create (aOwner : TComponent); override;
      destructor  Destroy; override;

      function  Safe : TComponent;
      function  New     (out   aReference;
                         const aObject : TObject) : IObjectSafe;
      procedure Guard   (const aObject : TObject);
      procedure Dispose (var   aReference) ;
    end;


constructor TObjectSafe.Create (aOwner : TComponent);
begin
  inherited Create (aOwner);
  AddObject := AddObjectAtEndOfList;
end;

destructor TObjectSafe.Destroy;
var
  aIndex     : Integer;
  aComponent : TComponent;
begin
  with ExceptionSafe do begin
    for aIndex := High(FObjects) downto Low (FObjects) do
      try
        FObjects[aIndex].Free;
      except
        SaveException;
      end;

    for aIndex := ComponentCount-1 downto 0 do
      try
        aComponent := Components[aIndex];
        try
          RemoveComponent(aComponent);
        finally
         aComponent.Free;
        end;
      except
        SaveException;
      end;

    try
      inherited Destroy;
    except
      SaveException;
    end;
  end;
end;

function TObjectSafe.Safe : TComponent;
begin
  Result := Self;
end;

procedure TObjectSafe.Guard (const aObject : TObject);
begin
  try
    if aObject is TComponent then begin
      if  TComponent(aObject).Owner <> Self  then
        InsertComponent(TComponent(aObject));
      end
    else
      AddObject(aObject);
  except
    aObject.Free;
    raise;
  end;
end;

function TObjectSafe.New (out aReference; const aObject : TObject) : IObjectSafe;
begin
  try
    Guard(aObject);

    TObject(aReference) := aObject;
  except
    TObject(aReference) := Nil;
    raise;
  end;

  Result := Self;
end;

procedure TObjectSafe.Dispose (var aReference);
begin
  try
    try
      if  TObject (aReference) is TComponent  then
        RemoveComponent(TComponent(TObject(aReference)))
      else
        RemoveObject(TObject(aReference));
    finally
      TObject(aReference).Free;
    end;
  finally
    TObject(aReference) := Nil;
  end;
end;



procedure TObjectSafe.AddObjectAtEndOfList (const aObject : TObject);
begin
  SetLength(FObjects, Length(FObjects)+1 );
  FObjects[High(FObjects)] := aObject;
end;

procedure TObjectSafe.AddObjectInEmptySlot (const aObject : TObject);
begin
  FObjects[FEmptySlots[High(FEmptySlots)]] := aObject;
  SetLength(FEmptySlots, High(FEmptySlots));

  if  Length(FEmptySlots) = 0  then
    AddObject := AddObjectAtEndOfList;
end;



procedure TObjectSafe.RemoveObject (const aObject : TObject);
var aIndex : Integer;
begin
  for aIndex := High (FObjects) downto Low (FObjects) do begin
    if  FObjects[aIndex] = aObject then begin
      FObjects [aIndex] := Nil;

      SetLength (FEmptySlots, Length(FEmptySlots)+1);
      FEmptySlots[High(FEmptySlots)] := aIndex;
      AddObject := AddObjectInEmptySlot;

      Exit;
    end;
  end;
end;

function ObjectSafe : IObjectSafe;
begin
  Result := TObjectSafe.Create (Nil);
end;

function ObjectSafe (out aObjectSafe : IObjectSafe) : IObjectSafe; overload;
begin
  aObjectSafe := ObjectSafe;
  Result := aObjectSafe;
end;

procedure SafeFreeAndNil(var AObject);
begin
  if Assigned(Pointer(AObject)) then
    FreeAndNil(AObject);
end;

procedure FreeStringListObjects(var ASl: TStringList);
var
  i: Integer;
begin
  for i:=0 to ASl.Count-1 do
    if Assigned(ASl.Objects[i]) then
      ASl.Objects[i].Free;
  ASl.Clear;
end;

end.
