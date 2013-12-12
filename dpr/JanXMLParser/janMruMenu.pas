unit janMruMenu;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, IniFiles;

type
   TSelFileEvent = procedure(Sender: TObject; FileName: string) of object;

   TMruLocation = (ml_ExeDirectory, ml_WindowsDirectory, ml_CurrentDirectory);

  TjanMruMenu = class(TComponent)
  protected
    FOnSelFile : TSelFileEvent;        // This event fires when the user selects an Mru file on the menu
    FMainMenu  : TMainMenu;            // The Parent Menu used to append the Mru file list
    FParGroup  : byte;                 // The GroupIndex of the Main Menu Item to append to (usually File = 0)
    FMruGroup  : byte;                 // Unique Group Num given to Mru Menu Items. Needed to delete ONLY the Mru Menu items.
    FNumFiles  : integer;              // Max number of Mru files (default is 4)
    FShowPath  : boolean;              // Determines if file Path is displayed in the menu
    Files      : TStringList;          // Holds the Mru files
    FMruLoc    : TMruLocation;
    OwnName    : string;
    MruItems   : TList;
    procedure  OnMenuClick(Sender: TObject);
    procedure  Loaded; override;
    procedure  UpdateMenu;
    procedure  Load_Files(const IniName: string);
    procedure  Save_Files(const IniName: string);
    function   MruFilePath: string;
    function   IniSectionName: string;
    procedure  Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure  AddFile(fn : string);
    procedure  ConnectToMenu;          // So the user can call it after changing all the properties
    procedure  Clear;                  // Resets all Mru file list to empty
  published
    { Published declarations }
    property OnSelectFile  : TSelFileEvent read FOnSelFile write FOnSelFile;
    property ParentMenu    : TMainMenu read FMainMenu write FMainMenu;
    property ParentGroup   : byte read FParGroup write FParGroup;
    property MruGroup      : byte read FMruGroup write FMruGroup;
    property NumFiles      : integer read FNumFiles write FNumFiles;
    property ShowPath      : boolean read FShowPath write FShowPath;
    property MruLocation   : TMruLocation read FMruLoc write FMruLoc;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('janBasic', [TjanMruMenu]);
end;

constructor TjanMruMenu.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);

   MruItems  := TList.Create;
   FParGroup := 0;                     // Default for "File" menu
   FMruGroup := 253;                   // This should be unique!
   FNumFiles := 4;
   FShowPath := False;
   Files     := TStringList.Create;
   FMainMenu := nil;
   FMruLoc   := ml_ExeDirectory;

   Assert(AOwner<>nil, 'IniSectionName: Owner = nil');
   OwnName   := AOwner.Name;
end;

destructor TjanMruMenu.Destroy;
begin
   // Save the Mru file list to the Mru file
   Save_Files(MruFilePath);

   // Unhook from the Main Menu
   // This is for the weird case where we get destroyed but the menu doesn't.
   // It would be dangerous because the Menu OnClick events would be invalid.
   // This section used to crash until I added a Notification handler.
   Files.Clear;
   UpdateMenu;

   Files.Free;
   MruItems.Free;
   inherited Destroy;
end;

function TjanMruMenu.IniSectionName: string;
begin
   Result := 'MRU_Files_' + OwnName;
end;

procedure TjanMruMenu.Load_Files(const IniName: string);
var
   ini      : TIniFile;
   i, Num   : integer;
   s        : string;
begin
   ini := TIniFile.Create(IniName);

   Num := ini.ReadInteger(IniSectionName, 'Count', 0);

   Files.Clear;
   for i := 0 to Num-1 do begin
      s := ini.ReadString(IniSectionName, 'File_'+IntToStr(i), '');
      Files.Add(s);
   end;

   ini.Free;
end;

procedure TjanMruMenu.Save_Files(const IniName: string);
var
   ini : TIniFile;
   i   : integer;
begin
   ini := TIniFile.Create(IniName);

   ini.WriteInteger(IniSectionName, 'Count', Files.Count);

   for i := 0 to Files.Count-1 do begin
      ini.WriteString(IniSectionName, 'File_'+IntToStr(i), Files[i]);
   end;

   ini.Free;
end;

procedure TjanMruMenu.AddFile(fn : string);
var
   i : integer;
begin
   // Delete file "fn" from Files (if its in there)
   i := Files.IndexOf(fn);
   if i<>-1 then Files.Delete(i);

   // Append "fn" to the top of Files (since it is the Most Recently Used)
   Files.Insert(0, fn);

   // Trim the oldest files if more than NumFiles
   while Files.Count > NumFiles do
      Files.Delete(Files.Count-1);           // -1 since its 0 indexed

   UpdateMenu;
end;

procedure TjanMruMenu.OnMenuClick(Sender: TObject);
var
   i    : integer;
   Save : string;
begin
   // Make sure OnSelectFile is "Assigned"
   if not Assigned(FOnSelFile) then exit;

   i := (Sender as TMenuItem).Tag;
   // Call the OnSelectFile event with the correct File Name
   Save := Files[i];
   FOnSelFile(Self, Save);

   // Bring it to the top of the list
   AddFile(Save);
end;

procedure TjanMruMenu.UpdateMenu;
var
   ParMenu : TMenuItem;
   M       : TMenuItem;
   i       : integer;
   s       : string;
begin
   // Make sure the menu exists
   if FMainMenu=nil then exit;

   // Don't do anything at design time
   if csDesigning in ComponentState then exit;

   // Find our Parent Menu using its Group Number
   ParMenu := nil;
   for i := 0 to FMainMenu.Items.Count-1 do
      if FMainMenu.Items[i].GroupIndex = FParGroup then begin
         ParMenu := FMainMenu.Items[i];
         break;
         end;
   if ParMenu=nil then exit; // raise Exception.Create('No Parent Menu with given Group Number');

   // Delete the old Mru files from the menu (if they are there)
   for i := 0 to MruItems.Count-1 do begin
      M := MruItems[i];
      M.Free;
   end;
   MruItems.Clear;

   if Files.Count=0 then exit;   // Don't want the seperator bar if there are no files

   // Add the seperator bar
   M              := TMenuItem.Create(Self);
   M.Caption      := '-';
   M.GroupIndex   := FMruGroup;
   ParMenu.Add(M);
   MruItems.Add(M);

   // Add the new files to the bottom of the menu
   for i := 0 to Files.Count-1 do begin
      if FShowPath then s := '&' + IntToStr(i+1) + ' ' + Files[i]
         else s := '&' + IntToStr(i+1) + ' ' + ExtractFileName(Files[i]);
      M            := TMenuItem.Create(Self);
      M.Caption    := s;
      M.GroupIndex := FMruGroup;
      M.OnClick    := OnMenuClick;
      M.Tag        := i;
      ParMenu.Add(M);

      MruItems.Add(M);
   end;
end;

procedure TjanMruMenu.Loaded;
begin
   ConnectToMenu;
end;

procedure TjanMruMenu.ConnectToMenu;
begin
   // Don't do anything at design time
   if csDesigning in ComponentState then exit;

   // Load in the Most Recently Used (Mru) files from the Mru file
   try
      Load_Files(MruFilePath);
   except
      on Exception do begin end;       // Do nothing
   end;

   // Append them to the parent Menu
   UpdateMenu;
end;

function TjanMruMenu.MruFilePath: string;
var
   WinDir   : array[0..MAX_PATH] of char;
   FMruFile : string;
begin
   GetWindowsDirectory(WinDir, sizeof(WinDir));
   if Copy(WinDir, Length(WinDir), 1)<>'\' then StrCat(WinDir, '\');
   FMruFile := ExtractFileName(Application.ExeName);
   FMruFile := ChangeFileExt(FMruFile, '.INI');

   case MruLocation of
      ml_ExeDirectory      : Result := ExtractFilePath(Application.ExeName) + FMruFile;
      ml_WindowsDirectory  : Result := WinDir + FMruFile;
      ml_CurrentDirectory  : Result := FMruFile;
   end;
end;

procedure TjanMruMenu.Clear;
begin
   Files.Clear;
   UpdateMenu;
end;

// This procedure is necessary to properly unhook from the MainMenu.
// It basically handles the message when the MainMenu is destroyed
// before the janMruMenu.

procedure TjanMruMenu.Notification(AComponent: TComponent; Operation: TOperation);
begin
   inherited Notification(AComponent, Operation);

   if (AComponent = ParentMenu) and (Operation = opRemove)
      then ParentMenu := nil;
end;


end.
