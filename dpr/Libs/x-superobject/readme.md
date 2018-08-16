



**Delphi Cross Platform Rapid JSON**
------------------------------------
[![](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=7BPTUUP4DGD5C)

###Basic
```json
{
  "name": "Onur YILDIZ", 
  "vip": true,
  "telephones": ["000000000", "111111111111"],
  "age": 24,
  "size": 1.72,
  "adresses": [
    {
      "adress": "blabla",
      "city": "Antalya",
      "pc": 7160
    },
    {
      "adress": "blabla",
      "city": "Adana",
      "pc": 1170
    }
  ]
}
```


----------


###Delphi Side

```pascal
// foo
var
  X: ISuperObject;
begin
  X := SO;
  X.S['name'] := 'Onur YILDIZ';
  X.B['vip'] := true;
  with X.A['telephones'] do
  begin
   Add('000000000');
   Add('111111111111');
  end;
  X.I['age'] := 24;
  X.F['size'] := 1.72;
  with X.A['adresses'].O[0] {Auto Create} do
  begin
    S['adress'] := 'blabla';
    S['city'] := 'Antalya';
    I['pc'] := 7160;
  end;
  // or
  X.A['adresses'].O[1].S['adress'] := 'blabla';
  X.A['adresses'].O[1].S['city'] := 'Adana';
  X.A['adresses'].O[1].I['pc'] := 1170;
```
----------
###Super Expressions
```pascal
const
  JSON = '{ "o": { '+
         '    "1234567890": {'+
         '    "last use date": "2010-10-17T01:23:20",'+
         '    "create date": "2010-10-17T01:23:20",'+
         '    "name": "iPhone 8s"'+
         '        }'+
         '  },'+
         '  "Index": 0, '+
         '  "Data": {"Index2": 1}, '+
         '  "a": [{'+
         '    "last use date": "2010-10-17T01:23:20",'+
         '    "create date": "2010-11-17T01:23:20",'+
         '    "name": "iPhone 8s",'+
         '    "arr": [1,2,3] '+
         '  }, '+
         '  {'+
         '    message: "hello"'+
         '  }]'+
         '}';

var
  X: ISuperObject;
  NewJSon: ISuperObject;
  NewArray: ISuperArray;
begin
  X := SO(JSON);
  ShowMessage( X['o."1234567890"."last use date"'].AsString );
  ShowMessage( X['a[Index]."create date"'].AsString );
  ShowMessage( X['a[Data.Index2].message'].AsString );
  X['a[0].arr'].AsArray.Add('test1');
  // -----
  NewJSON := X['{a: a[Index], b: a[Data.Index2].message, c: o."1234567890".name, d: 4, e: a[0].arr[2], f: " :) "}'].AsObject;
  NewArray := X['[a[Index], a[Data.Index2].message, Data.Index2, Index, 1, "1", "test"]'].AsArray;
end;
```
----------
###Where
```pascal
var
  FilterJSON: ISuperObject;
begin
  FilterJSON := SO('{ Table: [ '+
                   '   { '+
                   '      Name: "Sakar SHAKIR", ' +
                   '      Sex: "M",  ' +
                   '      Size: 1.75 '+
                   '   }, '+
                   '   {  '+
                   '      Name: "Bulent ERSOY", ' +
                   '      Sex: "F",  ' +
                   '      Size: 1.60 '+
                   '   }, '+
                   '   { '+
                   '      Name: "Cicek ABBAS", ' +
                   '      Sex: "M",  ' +
                   '      Size: 1.65 '+
                   '   } '+
                   '  ] '+
                   '}');
  Memo1.Lines.Add(
      FilterJSON.A['Table'].Where(function(Arg: IMember): Boolean 
      begin
        with Arg.AsObject do
             Result := (S['Sex'] = 'M') and (F['Size'] > 1.60)
      end).AsJSON
  );
end;
```

***Output***
```json
 [
    {
      "Name":"Sakar SHAKIR",
      "Sex":"M",
      "Size":1.75
    },
    {
      "Name":"Cicek ABBAS",
      "Sex":"M",
      "Size":1.65
    }
 ]
```
----------
###Delete
```pascal
var
  FilterJSON: ISuperObject;
begin
  FilterJSON := SO('{ Table: [ '+
                   '   { '+
                   '      Name: "Sakar SHAKIR", ' +
                   '      Sex: "M",  ' +
                   '      Size: 1.75 '+
                   '   }, '+
                   '   {  '+
                   '      Name: "Bulent ERSOY", ' +
                   '      Sex: "F",  ' +
                   '      Size: 1.60 '+
                   '   }, '+
                   '   { '+
                   '      Name: "Cicek ABBAS", ' +
                   '      Sex: "M",  ' +
                   '      Size: 1.65 '+
                   '   } '+
                   '  ] '+
                   '}');
  Memo1.Lines.Add(
      FilterJSON.A['Table'].Delete(function(Arg: IMember): Boolean 
      begin
        with Arg.AsObject do
             Result := (S['Sex'] = 'M') and (F['Size'] > 1.60)
      end).AsJSON
  );
end;
```
***Output***
```json
 [
    {
      "Name":"Bulent ERSOY",
      "Sex":"F",
      "Size":1.6
    }
 ]
```

----------
###Sorting
```pascal
var
  X: ISuperObject;
  A: ISuperArray;
begin
  X := SO('{b:1, a:2, d:4, c:2}');
  ShowMessage(X.AsJSON);
  X.Sort(function(Left, Right: IMember): Integer begin
    Result := CompareText(Left.Name, Right.Name);
  end);
  ShowMessage(X.AsJSON);

  A := SA('[{index:3}, {index:4}, {index:2}, {index:1}]');
  ShowMessage(A.AsJSON);
  A.Sort(function(Left, Right: IMember): Integer begin
    Result := CompareValue(Left.AsObject.I['index'], Right.AsObject.I['index']);
  end);
  ShowMessage(A.AsJSON);
end;
```
***Output***
```json
 {"b":1,"a":2,"d":4,"c":2}
 {"a":2,"b":1,"c":2,"d":4}
 [{"index":3},{"index":4},{"index":2},{"index":1}]
 [{"index":1},{"index":2},{"index":3},{"index":4}]
```
----------
###Variant
```pascal
var 
  X: ISuperObject;
begin 
  X := TSuperObject.Create;
  X.V['A'] := 1;
  X.V['B'] := '2';
  X.V['C'] := 1.3;
  X.V['D'] := False;
  X.V['E'] := Null;
  X.V['F'] := Now;
  Memo1.Lines.Add(X.AsJSON);
end;
```
***Output***
```json
 {
    "A": 1,
    "B": "2",
    "C": 1.3,
    "D": false,
    "E": null,
    "F": "2014-05-03T03:25:05.059"
 }
```
----------
###Loops
```pascal
const
  JSN = '{ '+
        ' "adresses": [ '+
        '   { '+
        '     "adress": "blabla", '+
        '     "city": "Antalya", '+
        '     "pc": 7160 '+
        '   },'+
        '   { '+
        '     "adress": "blabla", '+
        '     "city": "Adana", '+
        '     "pc": 1170 '+
        '   } '+
        ' ] '+
        '}';
var
  X, Obj: ISuperObject;
  J: Integer;
begin
  X := TSuperObject.Create(JSN);
  with X.A['adresses'] do
    for J := 0 to Lenght -1 do
    begin
      Obj := O[J];
      Obj.First;
      while not Obj.EoF do
      begin
         Memo1.Lines.Add( Obj.CurrentKey + ' = ' + VarToStr(Obj.CurrentValue.AsVariant));
         Obj.Next;
      end;
      Memo1.Lines.Add('------');
    end;
end;
```
> **Output**
> adress = blabla
> city = Antalya
> pc = 7160

**Or Enumerator**
```pascal
var
  X: ISuperObject;
  AMember,
  OMember: IMember;
begin
  X := TSuperObject.Create(JSN);

  for AMember in X.A['adresses'] do
  begin
      for OMember in AMember.AsObject do
          Memo1.Lines.Add(OMember.Name + ' = ' + OMember.ToString);

      Memo1.Lines.Add('------');
  end;
```
> **Output**
> adress = blabla
> city = Adana
> pc = 1170

----------
###Marshalling
```pascal
type

  TTestSet = (ttA, ttB, ttC);

  TTestSets = set of TTestSet;
 
  TSubRec = record
    A: Integer;
    B: String; 
  end;

  TSubObj = class
    A: Integer;
    B: Integer; 
  end;  
  
  TTest = class // Field, Property Support
  private
    FB: String;
    FSubObj: TSubObj;
    FSubRec: TSubRec;
    FTestSets: TTestSets;
    FH: TDateTime;
    FJ: TDate;
    FK: TTime;
    FList: TObjectList<TSubObj>; // or TList<>; But only object types are supported
  public
    A: Integer;
    B: TTestSet;
    C: Boolean;
    property D: String read FB write FB;
    property E: TSubRec read FSubRec write FSubRec;
    property F: TSubObj read FSubObj write FSubObj;
    property G: TTestSets read FTestSets write FTestSets;
    property H: TDateTime read FH write FH;
    property J: TDate read FJ write FJ;
    property K: TTime read FK write FK;
    property L: TObjectList<TSubObj> read FList write FList;
  end;
  
  TTestRec = record // Only Field Support
    A: Integer;
    B: TTestSet;
    C: Boolean;
    D: String;
    E: TSubRec;
    F: TSubObj;
    G: TTestSets;
    H: TDateTime;
    J: TDate;
    K: TTime;
    L: TObjectList<TSubObj>; // or TList<>; But only object types are supported
  end;
  
  implementation
  ...
  
  var 
    Parse: TTest; // For Class;
    S: String;
  begin
    Parse := TTest.FromJSON('{"A": 1, "B": 0, "C": true, "D": "Hello", "E":{"A": 3, "B": "Delphi"}, "F": {"A": 4, "B": 5}, "G": [0,2], "H": "2014-05-03T03:25:05.059", "J": "2014-05-03", "K": "03:25:05", "L":[{"A": 4, "B": 5},{"A": 6, "B": 7}] }');
    S := Parse.AsJSON;
  end;
  
  
  ...
  var
    Parse: TTestRec; // For Record;
    S: String;
  begin
    Parse := TJSON.Parse<TTestRec>('{"A": 1, "B": 0, "C": true, "D": "Hello", "E":{"A": 3, "B": "Delphi"}, "F": {"A": 4, "B": 5}, "G": [0,2], "H": "2014-05-03T03:25:05.059", "J": "2014-05-03", "K": "03:25:05", "L":[{"A": 4, "B": 5},{"A": 6, "B": 7}]}');  
    S := TJSON.Stringify<TTestRec>(Parse);
  end;
  
```
```pascal
type
  TRec = record // or class
    A: Integer;
    B: String;
  end;
  
  implementation
  ...
  
  var
    Test: TArray<TRec>;
    S: String;
  begin
    Test := TJSON.Parse<TArray<TRec>>('[{"A": 1, "B": "1"}, {"A": 2, "B": "2"}]');
    S := TJSON.Stringify<TArray<TRec>>(Test);
  end;
```
Collection (Limited)
```pascal
type
  TXCollectionItem = class(TCollectionItem)
  private
    FA: String;
    FB: Integer;
  public
    property A: String read FA write FA;
    property B: Integer read FB write FB;
  end;
  
  TXCollection = class(TCollection)
  public
    constructor Create; reintroduce;
  end;
  
  TTest = class
  private
    FCollection: TXColleciton;
  public
    destructor Destroy; override;
    property Collection: TCollection read FCollection write FCollection;
  end;
  
  implementation
  ...
  
  constructor TXCollection.Create;
  begin
    inherited Create(TXCollectionItem);
  end;
  
  destructor TTest.Destroy;
  begin
    FCollection.Free;
    inherited;
  end;
  
  var
    Test: TTest;
  begin
    Test := TTest.FromJSON('{"Collection": [{"A": "Item 1", "B": 1}, {"A": "Item 2", "B": 1}]}');
    S := Test.AsJSON;
  end;
```
----------
###Marshalling **Attributes**
```pascal
TTest = class 
  public
    [ALIAS('Type')]
     Typ: String;
    [ALIAS('Unit')]
     Unt: Integer;
    [REVAL('', '*')]
     Filter: String;
    [DISABLE]
     BlaBlaBla: String;
    [REVAL(roEmptyArrayToNull)]
     Arr: TArray<String>;
  end;

  var X: Test;
  begin
    X := TTest.Create;
    X.Typ := 'XType';
    X.Unt := 2;
    X.Filter := '';
    X.BlaBlaBla := ':)';
    SetLength(X.Arr, 0);
    ShowMessage(X.AsJSON);
  end;
```
***Output***
```json
 {
    "Type": "XType", 
    "Unit": 2, 
    "Filter": "*",
    "Arr": null
 }
```
