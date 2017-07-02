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
const
  BUFFER_LENGTH = 10 * SizeOf(inotify_event) + 256;
var
  Watch, EPollFd, Err: cint;  
  Buffer: Array[0..BUFFER_LENGTH - 1] of Char;
  BytesRead: TsSize;
  InotifyEvent: Pinotify_event;
  I: Integer;
  EPollEvent: Epoll_Event;
  Events: Array[0..0] of EPoll_Event;
  FileName, Directory, FullPath: String;
  EventType: TDirectoryEventType;
begin
  FInotifyFd := inotify_init;
  if FInotifyFd = -1 then
    Exit;

  AddWatchForDirectory(FDirectory, IGNORE_FILES_IN_SUB_DIRS);

  EPollFd := epoll_create(SizeOf(FInotifyFd));
  EPollEvent.Data.FD := FInotifyFd;
  EPollEvent.Events := EPOLLIN or EPOLLOUT or EPOLLET;

  Err := epoll_ctl(EPollFd, EPOLL_CTL_ADD, FInotifyFd, @EPollEvent);
  if Err < 0 then
    WriteLn('EPOLL_CTL ERROR ', ErrNo);

  while True do
  begin
    err := epoll_wait(EPollFd, @Events, 1, 100);

    if err = 0 then
    begin
      WriteLn('TimeOut!');

      if Terminated then
      begin
        WriteLn('Termination!');
        Exit;
      end;
    end
    else
    begin
      WriteLn('Something happened');
      WriteLn('EpollWait ', err);
      WriteLn('EPollEvent.Data.xFD ', Events[0].Data.FD);
      WriteLn('FInotifyFd ', FInotifyFd);
      Writeln(Events[0].Events);
    
      if Events[0].Data.FD = FInotifyFd then
      begin
        BytesRead := FpRead(FInotifyFd, @Buffer, BUFFER_LENGTH);
        WriteLn('BytesRead ', BytesRead);

        for I := 0 to BytesRead - 1 do
          if Buffer[I] < #32 then
            Write('#' + IntToStr(Byte(Buffer[I])))
          else
            Write(Buffer[I]);

        I := 0;
        while I < BytesRead do
        begin
          WriteLn('I = ', I);
          InotifyEvent := @Buffer[I];
          WriteLn('Event Length: ', InotifyEvent.len);
          WriteLn('Mask: ', InotifyEvent.mask);
          WriteLn('wd: ', InotifyEvent.wd);
          WriteLn('Name ', InotifyEvent.name);
        
          if FWatches.TryGetData(InotifyEvent.wd, Directory) then
          begin
            FileName := String(PChar(@Buffer[I] + SizeOf(inotify_event) - 1));  
            WriteLn('n2: ', Directory);
            WriteLn('n3: ', FileName);
          
            if (InotifyEvent.mask and IN_CREATE) > 0 then
              EventType := detAdded
            else if (InotifyEvent.mask and IN_DELETE) > 0 then
              EventType := detRemoved
            else if (InotifyEvent.mask and IN_MOVED_FROM) > 0 then
              EventType := detRemoved
            else if (InotifyEvent.mask and IN_MOVED_TO) > 0 then
              EventType := detAdded                                
            else
              EventType := detModified;

            FullPath := Directory + FileName;
            if not DirectoryExists(FullPath) then
              FOnGetData(FullPath, EventType)
            else if FWatchSubtree then
              AddWatchForDirectory(FullPath, TRIGGER_EVENT_FOR_ALL_FILES_IN_SUB_DIRS);
          end;

          I := I + SizeOf(inotify_event) + InotifyEvent.len - 1;
        end;     
      end;        
    end;      
  end;

  WriteLn('Done');
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

end.