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

implementation

uses
  SysUtils, SyncObjs, JwaWinBase, DirectoryWatcherThread.Windows;

destructor TDirectoryWatcherWindows.Destroy;
begin
  StopThread;
  inherited Destroy;
end;

procedure TDirectoryWatcherWindows.Start;
begin
  inherited;
  StartThread;
end;

procedure TDirectoryWatcherWindows.StartThread;
var
  ControlThread: TDirectoryWatcherThreadWindows;
begin  
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