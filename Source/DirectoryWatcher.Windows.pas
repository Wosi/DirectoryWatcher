unit DirectoryWatcher.Windows;

interface 

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

uses
  DirectoryWatcher;

type
  TDirectoryWatcherWindows = class(TDirectoryWatcher)
  private
    FTermEventName: String;
    procedure StartThread;
    procedure StopThread;
  public
    destructor Destroy; override;
    procedure Start; override;
  end;

  TDirectoryWatcher = TDirectoryWatcherWindows;
  
implementation

uses
  SysUtils, SyncObjs, JwaWinBase, DirectoryWatcherThread.Windows, DirectoryWatcherAPI;

destructor TDirectoryWatcherWindows.Destroy;
begin
  StopThread;
  inherited Destroy;
end;

procedure TDirectoryWatcherWindows.Start;
begin
  StartThread;
end;

procedure TDirectoryWatcherWindows.StartThread;
var
  ControlThread: TDirectoryWatcherThreadWindows;
begin
  if (Length(FDirectory) = 0) or (not DirectoryExists(FDirectory)) then
    raise EDirectoryWatcher.Create('TDirectoryWatcher: No or invalid folder');

  ControlThread := TDirectoryWatcherThreadWindows.Create(FDirectory, FRecursively, FEventHandler);
  FTermEventName := IntToStr(ControlThread.Handle) + 'N';
  ControlThread.Start;
end;

procedure TDirectoryWatcherWindows.StopThread;
var 
  StopEvent: TEvent;
begin
  StopEvent := TEvent.Create(Nil, False, False, FTermEventName);
  PulseEvent(Integer(StopEvent.Handle^));
  StopEvent.Free;
end;

end.