unit DirectoryWatcher.Linux;

interface

uses
  DirectoryWatcher, DirectoryWatcherThread.Linux;

type
  TDirectoryWatcherLinux = class(TDirectoryWatcher)
  private
    FThread: TDirectoryWatcherThreadLinux;
    procedure StartThread;
    procedure StopThread;
  public
    destructor Destroy; override;
    procedure Start; override;  
  end;
  
implementation

destructor TDirectoryWatcherLinux.Destroy;
begin
  StopThread;
  inherited;
end;

procedure TDirectoryWatcherLinux.Start;
begin
  inherited;
  StartThread;
end;

procedure TDirectoryWatcherLinux.StartThread;
begin
  FThread := TDirectoryWatcherThreadLinux.Create(FDirectory, FRecursively, FEventHandler);
  FThread.Start;
end;

procedure TDirectoryWatcherLinux.StopThread;
begin
//   FThread.TearDown;
  FThread.Terminate;
  FThread.Free;
end;

end.