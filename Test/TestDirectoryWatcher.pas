unit TestDirectoryWatcher;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  Classes, SysUtils, SyncObjs, fpcunit, testregistry, DirectoryWatcherAPI;

type
  TTestDirectoryWatcher = class(TTestCase)
  private
    FDirectoryWatcher: IDirectoryWatcher;
    FNotifications: TStringList; 
    FCriticalSection: TCriticalSection;
    FTestFolder: String;
    function GetNameForNewTestFolder: String;
    procedure DeleteTestFolder;
    procedure HandleEvent(const Path: String; const EventType: TDirectoryEventType);
    function EventToStr(const Path: String; const EventType: TDirectoryEventType): String;
    procedure WriteFile(const Path, Content: String);
    procedure CreateAndStartWatcher(const WatchRecursively: Boolean = False);
    procedure CreateAndStartWatcherIncludingSubFolders;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestFileAdded;
    procedure TestFileModified;
    procedure TestFileRemoved;
    procedure TestFileRenamed;
    procedure TestFileAddedInSubfolder;
    procedure TestFileAddedInNewCreatedSubfolder;
    procedure TestFileAddedInSubfolderWhichIsNotBeingWatched;
  end;

implementation

uses
  FileUtil, DirectoryWatcherBuilder;

const 
  EVENT_NAMES: array[TDirectoryEventType] of String = (
    'Added',
    'Removed',
    'Modified'
  );

procedure TTestDirectoryWatcher.SetUp;
begin
  FTestFolder := GetNameForNewTestFolder;
  CreateDir(FTestFolder);
  FCriticalSection := TCriticalSection.Create;
  FNotifications := TStringList.Create;          
end;

procedure TTestDirectoryWatcher.CreateAndStartWatcher(const WatchRecursively: Boolean);
begin
  FDirectoryWatcher := TDirectoryWatcherBuilder
                         .New
                         .WatchDirectory(FTestFolder)
                         .Recursively(WatchRecursively)
                         .OnChangeTrigger(HandleEvent)
                         .Build;

  FDirectoryWatcher.Start;                                                                   
  Sleep(500);             
end;

procedure TTestDirectoryWatcher.CreateAndStartWatcherIncludingSubFolders;
begin
  CreateAndStartWatcher(True);
end;

procedure TTestDirectoryWatcher.TearDown;
begin
  FDirectoryWatcher := Nil;
  FCriticalSection.Free;
  FNotifications.Free;
  DeleteTestFolder;
  FTestFolder := '';
end;

function TTestDirectoryWatcher.GetNameForNewTestFolder: String;
var
  Folder: String;
  FolderCount: Integer;
begin
  Folder := ExtractFilePath(ParamStr(0)) + 'TestFolder' + PathDelim;
  Result := Folder;

  FolderCount := 1;
  while DirectoryExists(Result) do
  begin
    Inc(FolderCount);
    Result := Folder + IntToStr(FolderCount);
  end;
end;

procedure TTestDirectoryWatcher.DeleteTestFolder;
begin
  if DeleteDirectory(FTestFolder, True) then
    RemoveDir(FTestFolder);
end;

procedure TTestDirectoryWatcher.HandleEvent(const Path: String; const EventType: TDirectoryEventType);
begin
  FCriticalSection.Enter;
  try
    FNotifications.Add(EventToStr(Path, EventType));
  finally
    FCriticalSection.Leave;
  end;
end;

function TTestDirectoryWatcher.EventToStr(const Path: String; const EventType: TDirectoryEventType): String;
begin
  Result := EVENT_NAMES[EventType] + ': ' + Path;
end;

procedure TTestDirectoryWatcher.WriteFile(const Path: String; const Content: String);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := Content;
    Lines.SaveToFile(Path);
  finally
    Lines.Free;
  end;
end;

procedure TTestDirectoryWatcher.TestFileAdded;
var
  FilePath: String;
begin
  CreateAndStartWatcher;
  FilePath := IncludeTrailingPathDelimiter(FTestFolder) + 'File1.txt';
  WriteFile(FilePath, '');
  CheckEquals(EventToStr(FilePath, detAdded), Trim(FNotifications.Text));
end;

procedure TTestDirectoryWatcher.TestFileModified;
var
  FilePath: String;
begin
  FilePath := IncludeTrailingPathDelimiter(FTestFolder) + 'File1.txt';
  WriteFile(FilePath, '');
  CreateAndStartWatcher;
  WriteFile(FilePath, 'Test');
  CheckEquals(EventToStr(FilePath, detModified), Trim(FNotifications.Text));
end;

procedure TTestDirectoryWatcher.TestFileRemoved;
var
  FilePath: String;
begin
  FilePath := IncludeTrailingPathDelimiter(FTestFolder) + 'File1.txt';
  WriteFile(FilePath, '');
  CreateAndStartWatcher;
  DeleteFile(FilePath);
  CheckEquals(EventToStr(FilePath, detRemoved), Trim(FNotifications.Text));
end;

procedure TTestDirectoryWatcher.TestFileRenamed;
var
  FilePath: String;
begin
  FilePath := IncludeTrailingPathDelimiter(FTestFolder) + 'File1.txt';
  WriteFile(FilePath, '');
  CreateAndStartWatcher;
  RenameFile(FilePath, FilePath + '.new');
  CheckEquals(2, FNotifications.Count, 'Received notifications: ' + FNotifications.Text);
  CheckEquals(EventToStr(FilePath, detRemoved), Trim(FNotifications[0]));
  CheckEquals(EventToStr(FilePath + '.new', detAdded), Trim(FNotifications[1]));
end;

procedure TTestDirectoryWatcher.TestFileAddedInSubfolder;
var
  FilePath: String;
begin
  CreateDir(IncludeTrailingPathDelimiter(FTestFolder) + 'SubFolder');
  CreateAndStartWatcherIncludingSubFolders;
  FilePath := IncludeTrailingPathDelimiter(FTestFolder) + 'SubFolder' + PathDelim + 'File1.txt';
  WriteFile(FilePath, '');
  CheckEquals(EventToStr(FilePath, detAdded), Trim(FNotifications.Text));
end;

procedure TTestDirectoryWatcher.TestFileAddedInSubfolderWhichIsNotBeingWatched;
var
  FilePath: String;
begin
  CreateDir(IncludeTrailingPathDelimiter(FTestFolder) + 'SubFolder');
  CreateAndStartWatcher;
  FilePath := IncludeTrailingPathDelimiter(FTestFolder) + 'SubFolder' + PathDelim + 'File1.txt';
  WriteFile(FilePath, '');
  CheckEquals(0, FNotifications.Count);
end;

procedure TTestDirectoryWatcher.TestFileAddedInNewCreatedSubfolder;
var
  FilePath: String;
begin
  CreateAndStartWatcherIncludingSubFolders;
  CreateDir(IncludeTrailingPathDelimiter(FTestFolder) + 'SubFolder');
  FilePath := IncludeTrailingPathDelimiter(FTestFolder) + 'SubFolder' + PathDelim + 'File1.txt';
  WriteFile(FilePath, '');
  CheckEquals(2, FNotifications.Count, 'Received notifications: ' + FNotifications.Text);
  CheckEquals(EventToStr(IncludeTrailingPathDelimiter(FTestFolder) + 'SubFolder', detAdded), Trim(FNotifications[0]));
  CheckEquals(EventToStr(FilePath, detAdded), Trim(FNotifications[1]));
end;

initialization
  RegisterTest(TTestDirectoryWatcher);

end.
