unit uvsDebug;

interface

uses
  SyncObjs;

type TDbgGetCustomObjInfo = function (obj: TObject):string;

var
  _DbgGetCustomObjInfo:TDbgGetCustomObjInfo;

procedure AddToLog(msg: string); overload;

procedure AddToLog(sProc, sVar: string; val: Variant); overload;

procedure AddToLog(sProc, sVar: string; ptr: Pointer); overload;

procedure AddToLogUT(sProc, sVar: string; ptr: Pointer); overload;

function UtGetFileName(bEtalon: boolean = false): string;

procedure UtSetAndClearFile(sFile: string);

procedure UtCheckFile;

procedure AddToLogStd(iStep: integer); overload; stdcall;


function AbsPath(sPath: string): string; forward;

procedure AddExceptionToLog(sProc: string);

procedure InitVsDbg(isDbg, bDoDbgLog: boolean; sDbgDir: string);

procedure DbgDbgLog(sFile, msg, msg2: string);

var
isDbg: Boolean;
doDbgLog:boolean;
sDbgDir:string;
bUnitTesting:boolean;
sUtFile:string;
cs: TCriticalSection;
bFakes: boolean;
sLastMsg: string;
LastMsgCount:Cardinal;

implementation


uses
  SysUtils, Windows, Classes, Dialogs;

//var
//  lastPid:integer;


procedure AddToLog(msg: string);overload;
var
fn:string;
F:TextFile;
sTimes: string;
begin
  if msg=sLastMsg then
  begin
    inc(LastMsgCount);
    exit;
  end;


  if LastMsgCount>0 then
  begin
    sTimes:=FormatDateTime('mmdd hh:nn:ss.zzz', Now)+Format(';%s; (%d times)'+#13#10, [sLastMsg, LastMsgCount]);
    LastMsgCount:=0;
  end
    else
      sTimes:='';

  sLastMsg:=msg;
  msg:=sTimes+FormatDateTime('mmdd hh:nn:ss.zzz', Now)+';'+msg;
  cs.Enter;
  try

    if not doDbgLog and (ExceptObject=nil) then
      exit;

   if not bUnitTesting then
    //Fn:=ExtractFilePath(GetModuleName(HInstance))+'testing\log_'+IntToStr(GetCurrentProcessId)+'.csv'
    Fn:=sDbgDir+'log_'+IntToStr(GetCurrentProcessId)+'.csv'
    else
      Fn:=UtGetFileName;

   //DbgDbgLog(Fn+'_dbgdbg', msg, Fn);


   ForceDirectories(ExtractFilePath(Fn));

   //DbgDbgLog(Fn+'_dbgdbg', 'ForceDirectories called '+msg, Fn);


    assignFile(f,fn);
    if FileExists(fn) then Append(f) else Rewrite(f);
    Writeln(f,msg);
    Flush(f);
    Closefile(f);
  finally
    cs.Leave;    
  end;

end;

procedure AddToLog(sProc, sVar: string; val: Variant);overload;
begin
  AddToLog(sProc+';'+sVar+';'+string(val));
end;

procedure AddToLog(sProc, sVar: string; ptr: Pointer);overload;
var
  sCustom: string;
begin
  cs.Enter;
  if @_DbgGetCustomObjInfo<>nil then
    sCustom:=_DbgGetCustomObjInfo(ptr);
  AddToLog(sProc+';'+sVar+';'+IntToHex(Integer(ptr), 8)+';'+sCustom);
  
  cs.Leave;
end;

procedure AddToLogUT(sProc, sVar: string; ptr: Pointer);
var
  sCustom: string;
begin
  if not bUnitTesting then
    exit;

  if @_DbgGetCustomObjInfo<>nil then
    sCustom:=_DbgGetCustomObjInfo(ptr);

  //AddToLog(sProc+';'+sVar+';'+IntToHex(Integer(ptr), 8)+';'+sCustom);
  AddToLog(sProc+';'+sVar+';'+sCustom);
end;

function UtGetFileName(bEtalon: boolean = false): string;
begin
  if not bEtalon then
    Result := ExtractFilePath(GetModuleName(HInstance))+'testing\ut\'+sUtFile+'.csv'
    else
      Result := ExtractFilePath(GetModuleName(HInstance))+'testing\utEta\'+sUtFile+'.csv';
end;

procedure UtSetAndClearFile(sFile: string);
begin
  sUtFile:=sFile;
  DeleteFile(pChar(UtGetFileName));
end;

function CompareFiles(const FirstFile, SecondFile: string): Boolean;
var
  f1, f2: TMemoryStream;
begin
  Result := false;
  f1 := TMemoryStream.Create;
  f2 := TMemoryStream.Create;
  try
    //��������� �����...
    f1.LoadFromFile(FirstFile);
    f2.LoadFromFile(SecondFile);
    if f1.Size = f2.Size then //���������� �� �������...
      //�������� ��������� � ������
      Result := CompareMem(f1.Memory, f2.memory, f1.Size);
  finally
    f2.Free;
    f1.Free;
  end
end;

procedure UtCheckFile;
begin
  Assert(CompareFiles(UtGetFileName(false), UtGetFileName(true)), 'UNIT TEST NOT PASSED! '+UtGetFileName);
end;

procedure AddToLogStd(iStep: integer);
begin
  AddToLog('ASM;Step;'+IntToStr(iStep));
end;

function AbsPath(sPath: string): string;
begin
  Result := ExtractFilePath(GetModuleName(HInstance))+sPath;
end;

procedure AddExceptionToLog(sProc: string);
begin
  AddToLog(sProc,  'EXCEPTION', ExceptObject.ClassName);
end;

procedure InitVsDbg(isDbg, bDoDbgLog: boolean; sDbgDir: string);
begin
  //cs:=TCriticalSection.Create;

  uvsDebug.isDbg:=isDbg;
  uvsDebug.doDbgLog:=bDoDbgLog;
  uvsDebug.sDbgDir:=sDbgDir;
end;

procedure DbgDbgLog(sFile, msg, msg2: string);
var
  f: TextFile;
begin
    assignFile(f,sFile);
    if FileExists(sFile) then Append(f) else Rewrite(f);
    Writeln(f,''#13#10+msg+';'+msg2);
    Flush(f);
    Closefile(f);
end;


initialization
  cs:=TCriticalSection.Create;
finalization
begin
  FreeAndNil(cs);
end;

end.
