unit DirectoryWatcherAPI;

interface

uses
  SysUtils;

type
  TDirectoryEventType = (
    detAdded,
    detRemoved,
    detModified);

  TDirectoryEvent = procedure(const Path: String; const EventType: TDirectoryEventType) of object;

  IDirectoryWatcher = interface
    ['{590A0F34-800E-4116-AA30-2887876579A8}']
    procedure Start;
    function GetDirectory: String;
    function GetWatchSubdirectories: Boolean;
    property Directory: String read GetDirectory;
    property WatchSubdirectories: Boolean read GetWatchSubdirectories;
  end;

  IDirectoryWatcherBuilder = interface
    ['{C05905BE-7FA0-40C9-B1F4-7EC7E4DE2E91}']
    function WatchDirectory(const Directory: String): IDirectoryWatcherBuilder;
    function Recursively(const Value: Boolean): IDirectoryWatcherBuilder;
    function OnChangeTrigger(const Callback: TDirectoryEvent): IDirectoryWatcherBuilder;
    function Build: IDirectoryWatcher;
  end;

  EDirectoryWatcher = class(Exception);
  
implementation

end.