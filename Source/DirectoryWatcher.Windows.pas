unit DirectoryWatcher.Windows;

interface 

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

uses
  SysUtils, Classes, DirectoryWatcherThread.Windows, SyncObjs, jwawinbase, DirectoryWatcherAPI, DirectoryWatcher;

type
  TDirectoryWatcherWindows = class(TDirectoryWatcher, IDirectoryWatcher)
  private
    FTermEventName: String;
    procedure StartThread;
    procedure StopThread;
  public
    destructor Destroy; override;
    procedure Start; override;
  end;
  
implementation

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