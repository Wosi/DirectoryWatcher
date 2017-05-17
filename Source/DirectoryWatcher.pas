unit DirectoryWatcher;

interface 

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

uses
  SysUtils, Classes, DirectoryWatcherThread, SyncObjs, jwawinbase, DirectoryWatcherAPI;

type
  TDirectoryWatcherBuilder = class(TInterfacedObject, IDirectoryWatcherBuilder)
  private
    FDirectory: String;
    FRecursively: Boolean;
    FCallBack: TDirectoryEvent;
  public
    class function New: IDirectoryWatcherBuilder;
    function WatchDirectory(const Directory: String): IDirectoryWatcherBuilder;
    function Recursively(const Value: Boolean): IDirectoryWatcherBuilder;
    function OnChangeTrigger(const Callback: TDirectoryEvent): IDirectoryWatcherBuilder;
    function Build: IDirectoryWatcher;
  end;

  TDirectoryWatcher = class(TInterfacedObject, IDirectoryWatcher)
  private
    FDirectory: String;
    FTermEventName: String;
    FRecursively: Boolean;
    FEventHandler: TDirectoryEvent;
    procedure StartThread;
    procedure StopThread;
  public
    constructor Create(const Directory: String; const Recursively: Boolean; const EventHandler: TDirectoryEvent); 
    destructor Destroy; override;
    procedure Start;    
  end;

  EDirectoryWatcher = class(Exception);
  
implementation
 
constructor TDirectoryWatcher.Create(const Directory: String; const Recursively: Boolean; const EventHandler: TDirectoryEvent);
begin
  inherited Create;
  FDirectory := Directory;
  FRecursively := Recursively;
  FEventHandler := EventHandler;
end;

destructor TDirectoryWatcher.Destroy;
begin
  StopThread;
  inherited Destroy;
end;

procedure TDirectoryWatcher.Start;
begin
  StartThread;
end;

procedure TDirectoryWatcher.StartThread;
var
  ControlThread: TDirectoryWatcherThread;
begin
  if (Length(FDirectory) = 0) or (not DirectoryExists(FDirectory)) then
    raise EDirectoryWatcher.Create('TDirectoryWatcher: No or invalid folder');

  ControlThread := TDirectoryWatcherThread.Create(FDirectory, FRecursively, FEventHandler);
  FTermEventName := IntToStr(ControlThread.Handle) + 'N';
  ControlThread.Start;
end;

procedure TDirectoryWatcher.StopThread;
var 
  StopEvent: TEvent;
begin
  StopEvent:=TEvent.Create(nil,FALSE,FALSE,FTermEventName);
  PulseEvent(Integer(StopEvent.Handle^));
  StopEvent.Free;
end;

class function TDirectoryWatcherBuilder.New: IDirectoryWatcherBuilder;
begin
  Result := TDirectoryWatcherBuilder.Create;
end;

function TDirectoryWatcherBuilder.WatchDirectory(const Directory: String): IDirectoryWatcherBuilder;
begin
  FDirectory := Directory;
  Result := Self;
end;

function TDirectoryWatcherBuilder.Recursively(const Value: Boolean): IDirectoryWatcherBuilder;
begin
  FRecursively := Value;
  Result := Self;
end;

function TDirectoryWatcherBuilder.OnChangeTrigger(const Callback: TDirectoryEvent): IDirectoryWatcherBuilder;
begin
  FCallBack := Callback;
  Result := Self;
end;

function TDirectoryWatcherBuilder.Build: IDirectoryWatcher;
begin
  Result := TDirectoryWatcher.Create(FDirectory, FRecursively, FCallBack);
end;

end.