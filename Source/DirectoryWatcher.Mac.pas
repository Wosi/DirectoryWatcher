unit DirectoryWatcher.Mac;

interface

uses
  DirectoryWatcher, Classes;

type
  TDirectoryWatcherMac = class(TDirectoryWatcher)
  private
    FThread: TThread;
    procedure StartThread;
    procedure StopThread;
  public
    destructor Destroy; override;
    procedure Start; override;
  end;

implementation

uses
  DirectoryWatcherThread.Mac;

destructor TDirectoryWatcherMac.Destroy;
begin
  StopThread;
  inherited;
end;

procedure TDirectoryWatcherMac.Start;
begin
  inherited;
  StartThread;
end;

procedure TDirectoryWatcherMac.StartThread;
begin
  FThread := TDirectoryWatcherThreadMac.Create(FDirectory, FRecursively, FEventHandler);
  FThread.Start;
end;

procedure TDirectoryWatcherMac.StopThread;
begin
  (FThread as TDirectoryWatcherThreadMac).TearDown;
  FThread.Terminate;
  FThread.Free;
end;

end.