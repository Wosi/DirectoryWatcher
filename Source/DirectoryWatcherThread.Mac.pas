unit DirectoryWatcherThread.Mac;

{$mode Delphi}{$H+}
{$modeswitch objectivec1} 
{$SMARTLINK ON}
{$MACRO ON}

interface
  
uses
  Classes, MacOSAll, DirectoryWatcherAPI, CocoaAll;//, FSEvents;

type
  TCallback = procedure(streamRef: ConstFSEventStreamRef; clientCallBackInfo: UnivPtr; numEvents: size_t; eventPaths: UnivPtr; {const} eventFlags: {variable-size-array} FSEventStreamEventFlagsPtr; {const} eventIds: {variable-size-array} FSEventStreamEventIdPtr); cdecl;// {$IFDEF FPC} mwpascal; {$ENDIF}

  TDirectoryWatcherThreadMac = class(TThread)
  private
    FDirectory : String;
    FWatchSubtree: Boolean;
    FOnGetData: TDirectoryEvent;  
    FStream: FSEventStreamRef;
    RunLoop: CFRunLoopRef;
    callbackinfo : FSEventStreamContext;
    procedure HandleEvents(NumEvents: size_t; EventPaths: UnivPtr; EventFlags: FSEventStreamEventFlagsPtr);
    function FlagToEventType(const Flag: Integer; const Path: String): TDirectoryEventType;
  protected
    procedure Execute; override;
  public
    constructor Create(const Directory: String; const WatchSubtree: Boolean; const OnGetData: TDirectoryEvent);
    procedure TearDown;
  end;

implementation

uses
  cThreads, SysUtils;

constructor TDirectoryWatcherThreadMac.Create(const Directory: String; const WatchSubtree: Boolean; const OnGetData: TDirectoryEvent);
begin
  inherited Create(True);
  FDirectory := ExcludeTrailingPathDelimiter(Directory);
  FWatchSubtree := WatchSubtree;
  FOnGetData := OnGetData;
  FreeOnTerminate := False;
end;

procedure EventsCallback(StreamRef: ConstFSEventStreamRef; 
  ClientCallBackInfo: UnivPtr; NumEvents: size_t; EventPaths: UnivPtr; EventFlags: 
  FSEventStreamEventFlagsPtr; EventIds: FSEventStreamEventIdPtr); cdecl;
var
  Thread: TDirectoryWatcherThreadMac;
begin
  Thread := ClientCallBackInfo;
  Thread.HandleEvents(NumEvents, EventPaths, EventFlags);
end;  

procedure TDirectoryWatcherThreadMac.Execute;
var
  Pool: NSAutoreleasePool;
  PathsToWatch : CFArrayRef;
  WatchedDirectory : CFStringRef;
  Latency : CFAbsoluteTime;
begin
  Pool := NSAutoreleasePool.alloc.init;

  Latency := 0.1;
  WatchedDirectory := CFSTR(PChar(FDirectory));
  PathsToWatch := CFArrayCreate(Nil, @WatchedDirectory, 1, Nil);

  callbackinfo.info := Self;

  FStream := FSEventStreamCreate(Nil,
                                 @EventsCallback,
                                 @callbackinfo,
                                 PathsToWatch,
                                 UINT64($FFFFFFFFFFFFFFFF),
                                 Latency,
                                 kFSEventStreamCreateFlagFileEvents);

  RunLoop := CFRunLoopGetCurrent;
  FSEventStreamScheduleWithRunLoop(FStream, RunLoop, kCFRunLoopDefaultMode);
  FSEventStreamStart(FStream);
  
  CFRunLoopRun;
  Pool.release;
end;

procedure TDirectoryWatcherThreadMac.TearDown;
begin
  FSEventStreamStop(FStream);
  CFRunLoopStop(RunLoop);
end;

procedure TDirectoryWatcherThreadMac.HandleEvents(NumEvents: size_t; EventPaths: UnivPtr; EventFlags: FSEventStreamEventFlagsPtr);
var
  I : integer;
  Paths : PPCharArray;
  Flags : PIntegerArray;
  Path: String;
  EventType: TDirectoryEventType;
begin
  if Terminated then
    Exit;

  Paths := PPCharArray(EventPaths);
  Flags := PIntegerArray(EventFlags);
  for I := 0 to NumEvents -1 do
  begin
    if (Flags[I] and kFSEventStreamEventFlagItemIsFile) <> 0 then
    begin
      Path := Paths[I];
      if FWatchSubtree or AnsiSameText(FDirectory, ExtractFileDir(Path)) then
      begin
        EventType := FlagToEventType(Flags[I], Path);
        FOnGetData(Path, EventType);                              
      end;
    end;                       
  end;  
end;

function TDirectoryWatcherThreadMac.FlagToEventType(const Flag: Integer; const Path: String): TDirectoryEventType;
begin

  if (Flag and kFSEventStreamEventFlagItemRenamed) <> 0 then
    if FileExists(Path) then
      Exit(detAdded)
    else
      Exit(detRemoved);

  if (Flag and kFSEventStreamEventFlagItemRemoved) <> 0 then
    Exit(detRemoved);

  if (Flag and kFSEventStreamEventFlagItemModified) <> 0 then
    Exit(detModified);

  if (Flag and kFSEventStreamEventFlagItemCreated) <> 0 then
    Exit(detAdded);

  Exit(detModified);
end;
 
end.