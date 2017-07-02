unit DirectoryWatcherThread.Linux;

{$mode Delphi}

interface

uses
  Classes, DirectoryWatcherAPI, Linux, UnixType, FGL;

type
  TDirectoryWatcherThreadLinux = class(TThread)
  private
    FDirectory : String;
    FWatchSubtree: Boolean;
    FOnGetData: TDirectoryEvent;  
  protected
    procedure Execute; override;
  public
    constructor Create(const Directory: String; const WatchSubtree: Boolean; const OnGetData: TDirectoryEvent);
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
end;

procedure TDirectoryWatcherThreadLinux.Execute;
const
  BUFFER_LENGTH = 10 * SizeOf(inotify_event) + 256;
var
  InotifyFd, Watch, EPollFd, Err: cint;
  Watches: TFPGMap<cint, String>;
  Buffer, WdBuffer: Array[0..BUFFER_LENGTH - 1] of Char;
  BytesRead, WdBytesRead: TsSize;
  InotifyEvent: Pinotify_event;
  I: Integer;
  EPollEvent: Epoll_Event;
  Events: Array[0..0] of EPoll_Event;
  FileName, Directory: String;
  EventType: TDirectoryEventType;
begin
  InotifyFd := inotify_init;
  if InotifyFd = -1 then
    Exit;

  Watches := TFPGMap<cint, String>.Create;
  try
    Watch := inotify_add_watch(InotifyFd, PChar(FDirectory), IN_MODIFY or IN_CREATE or IN_DELETE or IN_MOVED_FROM or IN_MOVED_TO);
    if Watch > -1 then
      Watches.Add(Watch, IncludeTrailingPathDelimiter(FDirectory));

    WriteLn(InotifyFd, ' Watch is ', Watch, ' for ', FDirectory);

    // Read(InotifyFd, Buffer[0]);
    EPollFd := epoll_create(SizeOf(InotifyFd));
    // InotifyEvent.mask := EPOLLIN 
    //                   or EPOLLERR;

    EPollEvent.Data.FD := InotifyFd;
    EPollEvent.Events := EPOLLIN or EPOLLOUT or EPOLLET;
    Err := epoll_ctl(EPollFd, EPOLL_CTL_ADD, InotifyFd, @EPollEvent);
    
    if Err < 0 then
      WriteLn('EPOLL_CTL ERROR ', ErrNo);
    // epoll_ctl(EPollFd)

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
        WriteLn('InotifyFd ', InotifyFd);
        Writeln(Events[0].Events);
        // WriteLn(InotifyEvent.name);
      
        if Events[0].Data.FD = InotifyFd then
        begin
          BytesRead := FpRead(InotifyFd, @Buffer, BUFFER_LENGTH);
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
          
            if Watches.TryGetData(InotifyEvent.wd, Directory) then
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

              FOnGetData(Directory + FileName, EventType);
            end;

            //  WdBytesRead := FpRead(InotifyEvent.wd, @WdBuffer, BUFFER_LENGTH);
            //  WriteLn('WDBUFFER: ' + WdBuffer);

            I := I + SizeOf(inotify_event) + InotifyEvent.len - 1;
          end;     
        end;        
      end;      
    end;
  finally
    for I := 0 to Watches.Count - 1 do
      inotify_rm_watch(InotifyFd, Watches.Keys[I]);
    Watches.Free;
  end;

  WriteLn('Done');
end;

end.