unit FileVersion;

interface

type

  TVerInfo=packed record
    Dummy: array[0..47] of byte; // �������� ��� 48 ����
    Minor,Major,Build,Release: word; // � ��� ������
  end;

  TFileVersion = class(TObject)
  private
    Build: Word;
    Major: Word;
    Minor: Word;
    Release: Word;
    function DllVersion(FileName: PWideChar): Boolean;
    procedure GetVersion1;
  public
    v:TVerInfo;
    constructor Create(sFile: string);
  end;

implementation

uses
  System.Classes, Windows, System.SysUtils;

constructor TFileVersion.Create(sFile: string);
begin
  //GetVersion1;
  DllVersion(pChar(sFile));
end;

procedure TFileVersion.GetVersion1;
                        //http://www.delphilab.ru/content/view/78/63/
                        // by Snowy

var
  s:TResourceStream;
begin

  try
    s:=TResourceStream.Create(HInstance,'#1', 'RT_VERSION'); // ������ ������
    if s.Size>0 then begin
      s.Read(v,SizeOf(v)); // ������ ������ ��� �����
      //result:=IntToStr(v.Major)+'.'+IntToStr(v.Minor)+'.'+ // ��� � ������...
        //      IntToStr(v.Release)+'.'+IntToStr(v.Build);
    end;
  s.Free;
  except; end;
end;

{procedure TFileVersion.GetVersion2;
        const
            Prefix = '\StringFileInfo\040904E4\';
        var
            FData              : Pointer;
            FSize              : LongInt;
            FIHandle           : THandle;
            FFileName          : string;
            FFileVersion       : string;

        function GetVerValue(Value: string):string;
        var
          ItemName: string;
          Len   : Cardinal;
          vVers : Pointer;
        begin
          ItemName := Prefix + Value;
          Result := '';

          if VerQueryValue(FData, PChar(ItemName), vVers, Len) then
             if Len > 0 then begin
                if Len > 255 then
                   Len := 255;
                Result := Copy(PChar(vVers), 1 , Len);
             end;
        end;

        function GetFileVersion: string;
        begin
          if FSize > 0 then begin
             GetMem(FData, FSize);
             try
               if GetFileVersionInfo(PChar(FFileName), FIHandle, FSize, FData) then begin
                 FFileVersion:= GetVerValue('FileVersion');
               end;
             finally
               FreeMem(FData, FSize);
             end;
          end;
          Result := FFileVersion;
        end;

    begin
        Result := '';
        if FileExists( fName ) then begin
           FFileName := fName;
           FSize := GetFileVersionInfoSize(PChar(FFileName), FIHandle);
           Result := GetFileVersion;
        end;
    end; { function }  //}

function TFileVersion.DllVersion(FileName: PWideChar): Boolean;
var                          //http://www.delphilab.ru/content/view/78/63/
  Size, Size2: LongWord;
  Pt, Pt2: Pointer;
begin
    Result:=False;
     Size:=GetFileVersionInfoSizeW(FileName,Size2);
    if Size>0 then
    begin
      GetMem(Pt,Size);
      try
         GetFileVersionInfoW(FileName,0,Size,Pt);
        VerQueryValueW(Pt,'\',Pt2,Size2);
        with  TVSFixedFileInfo(Pt2^) do begin
           Major:=HiWord(dwFileVersionMS); //�����
           Minor:=LoWord(dwFileVersionMS); //�����
           Release:=HiWord(dwFileVersionLS); //��������
           Build:=LoWord(dwFileVersionLS); //����
        end;
        Result:=True;
      finally
        FreeMem(Pt,Size);
      end;
    end;
end;



end.
