program DirectoryWatcherDemo;

{$mode Delphi}{$H+}

uses
  {$IFDEF UNIX}cthreads{$ENDIF}
  Classes, SysUtils, CustApp, DirectoryWatcherBuilder, DirectoryWatcherAPI;

type
  TDirectoryWatcherDemo = class(TCustomApplication)
  private
    procedure OnFileEvent(const FilePath: String; const EventType: TDirectoryEventType);
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

procedure TDirectoryWatcherDemo.DoRun;
var
  FolderToWatch: String;
  WatchSubFolders: Boolean;
  DirectoryWatcher: IDirectoryWatcher;
begin
  FolderToWatch := GetOptionValue('folder');
  if FolderToWatch = '' then
    FolderToWatch := ExtractFileDir(ParamStr(0));

  WatchSubFolders := HasOption('r', 'recursive');

  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;
  
  DirectoryWatcher := TDirectoryWatcherBuilder
                        .New
                        .WatchDirectory(FolderToWatch)
                        .Recursively(WatchSubFolders)
                        .OnChangeTrigger(OnFileEvent)
                        .Build;

  DirectoryWatcher.Start;
  
  Write('Watching changes in ' + FolderToWatch);
  if WatchSubFolders then
    WriteLn(' including sub folders.')
  else
    WriteLn('.');

  WriteLn('Press <RETURN> to stop the program');
  ReadLn;

  Terminate;
end;

constructor TDirectoryWatcherDemo.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException := True;
end;

destructor TDirectoryWatcherDemo.Destroy;
begin
  inherited Destroy;
end;

procedure TDirectoryWatcherDemo.WriteHelp;
begin
  writeln('Usage: ', ExeName, ' --folder=FolderToWatch [-r]');
end;

procedure TDirectoryWatcherDemo.OnFileEvent(const FilePath: String; const EventType: TDirectoryEventType);
var
  EventTypeString: String;
begin
  WriteLn('======NEW EVENT======');
  WriteLn('File: ' + FilePath);

  case EventType of
    detAdded: EventTypeString := 'ADDED';
    detRemoved: EventTypeString := 'REMOVED';
    detModified: EventTypeString := 'MODIFIED';
  end;

  WriteLn('Type: ' + EventTypeString);
end;

var
  Application: TDirectoryWatcherDemo;
begin
  Application := TDirectoryWatcherDemo.Create(nil);
  Application.Title := 'DirectoryWatcherDemo';
  Application.Run;
  Application.Free;
end.

