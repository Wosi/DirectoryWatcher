unit DirectoryWatcherThread.Linux;

{$mode Delphi}

interface

uses
  Classes, DirectoryWatcherAPI, Linux, UnixType, FGL;

type
  TDirectoryWatcherThreadLinux = class(TThread)
  private const
    IGNORE_FILES_IN_SUB_DIRS = False;
    TRIGGER_EVENT_FOR_ALL_FILES_IN_SUB_DIRS = True;
  private
    FDirectory : String;
    FWatchSubtree: Boolean;
    FOnGetData: TDirectoryEvent;
    FWatches: TFPGMap<cint, String>;
    FInotifyFd: cint;
    procedure AddWatchesForSubDirectories(const BaseDir: String; const TriggerEventsForFiles: Boolean);
    procedure AddWatchForDirectory(const Directory: String; const TriggerEventsForFilesInSubFolders: Boolean);
    function InitializeINotify: Boolean;
    function InitializeEPoll: cint;
    procedure ReadAndHandleINotifyEvents;
    function INotifyEventMaskToEventType(const Mask: cuint32): TDirectoryEventType;
    procedure HandleINotifyEvent(const FilePath: String; const EventType: TDirectoryEventType);
  protected
    procedure Execute; override;
  public
    constructor Create(const Directory: String; const WatchSubtree: Boolean; const OnGetData: TDirectoryEvent);
    destructor Destroy; override;
  end;

implementation

uses
  baseunix, SysUtils;

constructor TDirectoryWatcherThreadLinux.Create(const Directory: String; const WatchSubtree: Boolean; const OnGetData: TDirectoryEvent);
begin
  inherited Create(True);
  FDirectory := Directory;
  FWatchSubtree := WatchSubtree;
  FOnGetData := OnGetData;
  FWatches := TFPGMap<cint, String>.Create;
end;

destructor TDirectoryWatcherThreadLinux.Destroy;
var
  I: Integer;
begin
  for I := 0 to FWatches.Count - 1 do
    inotify_rm_watch(FInotifyFd, FWatches.Keys[I]);
 
  FWatches.Free;
  inherited;
end;

procedure TDirectoryWatcherThreadLinux.Execute;
var
  EPollFd, WaitResult: cint; 
  Events: array[0..9] of EPoll_Event; 
begin
  if not InitializeINotify then
    Exit;

  AddWatchForDirectory(FDirectory, IGNORE_FILES_IN_SUB_DIRS);
  EPollFd := InitializeEPoll;

  while True do
  begin
    WaitResult := epoll_wait(EPollFd, @Events, Length(Events), 100);

    if Terminated then
      Exit;

    if WaitResult > 0 then
      if Events[0].Data.FD = FInotifyFd then
        ReadAndHandleINotifyEvents;   
  end;
end;

function TDirectoryWatcherThreadLinux.InitializeINotify: Boolean;
begin
  FInotifyFd := inotify_init;
  Result := FInotifyFd >= 0;
end;

procedure TDirectoryWatcherThreadLinux.AddWatchesForSubDirectories(const BaseDir: String; const TriggerEventsForFiles: Boolean);
var
  Info : TSearchRec;
  FilePath: String;
begin     
  if FindFirst(IncludeTrailingPathDelimiter(BaseDir) + '*', faDirectory, Info)=0 then
  begin
    repeat 
      if (Info.Name<>'') and (Info.Name[1]<>'.') then
      begin
        FilePath := IncludeTrailingPathDelimiter(BaseDir) + Info.Name;
        if (Info.Attr and faDirectory > 0) then
          AddWatchForDirectory(FilePath, TriggerEventsForFiles)
        else if TriggerEventsForFiles then
          FOnGetData(FilePath, detAdded);
      end;
    until FindNext(info)<>0;
  end;

  FindClose(Info);     
end;

procedure TDirectoryWatcherThreadLinux.AddWatchForDirectory(const Directory: String; const TriggerEventsForFilesInSubFolders: Boolean);
var
  Watch: cint;
begin
  Watch := inotify_add_watch(FInotifyFd, PChar(Directory), IN_MODIFY or IN_CREATE or IN_DELETE or IN_MOVED_FROM or IN_MOVED_TO);
  if Watch > -1 then
    FWatches.Add(Watch, IncludeTrailingPathDelimiter(Directory));  

  if FWatchSubtree then
    AddWatchesForSubDirectories(Directory, TriggerEventsForFilesInSubFolders);
end;

function TDirectoryWatcherThreadLinux.InitializeEPoll: cint;
var
  EPollEvent: Epoll_Event;
begin
  Result := epoll_create(SizeOf(cint));
  EPollEvent.Data.FD := FInotifyFd;
  EPollEvent.Events := EPOLLIN or EPOLLOUT or EPOLLET;
  epoll_ctl(Result, EPOLL_CTL_ADD, FInotifyFd, @EPollEvent);
end;

procedure TDirectoryWatcherThreadLinux.ReadAndHandleINotifyEvents;
const
  BUFFER_LENGTH = 10 * SizeOf(inotify_event) + 256;
var
  Buffer: Array[0..BUFFER_LENGTH - 1] of Char;
  BytesRead: TsSize;
  INotifyEvent: Pinotify_event;
  I: Integer;
  FileName, Directory, FullPath: String;
  EventType: TDirectoryEventType;
begin
  BytesRead := FpRead(FInotifyFd, @Buffer, BUFFER_LENGTH);

  I := 0;
  while I < BytesRead do
  begin
    INotifyEvent := @Buffer[I];
  
    if FWatches.TryGetData(INotifyEvent.wd, Directory) then
    begin
      EventType := INotifyEventMaskToEventType(INotifyEvent.mask);
      FileName := String(PChar(@Buffer[I] + SizeOf(inotify_event) - 1));                  
      FullPath := Directory + FileName;
      HandleINotifyEvent(FullPath, EventType);
    end;

    I := I + SizeOf(inotify_event) + INotifyEvent.len - 1;
  end;  
end;

function TDirectoryWatcherThreadLinux.INotifyEventMaskToEventType(const Mask: cuint32): TDirectoryEventType;
begin
  if (Mask and IN_CREATE) > 0 then
    Result := detAdded
  else if (Mask and IN_DELETE) > 0 then
    Result := detRemoved
  else if (Mask and IN_MOVED_FROM) > 0 then
    Result := detRemoved
  else if (Mask and IN_MOVED_TO) > 0 then
    Result := detAdded                                
  else
    Result := detModified;
end;

procedure TDirectoryWatcherThreadLinux.HandleINotifyEvent(const FilePath: String; const EventType: TDirectoryEventType);
begin
  if not DirectoryExists(FilePath) then
    FOnGetData(FilePath, EventType)
  else if FWatchSubtree and (EventType = detAdded) then
    AddWatchForDirectory(FilePath, TRIGGER_EVENT_FOR_ALL_FILES_IN_SUB_DIRS);
end;

end.