unit DirectoryWatcher.Mac;

interface

uses
  DirectoryWatcher, DirectoryWatcherThread.Mac, Classes;

type
  TDirectoryWatcherMac = class(TDirectoryWatcher)
  private
    FThread: TDirectoryWatcherThreadMac;
    procedure StartThread;
    procedure StopThread;
  public
    destructor Destroy; override;
    procedure Start; override;
  end;

implementation

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
  FThread.TearDown;
  FThread.Terminate;
  FThread.Free;
end;

end.