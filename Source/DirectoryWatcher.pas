unit DirectoryWatcher;

interface 

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

uses
  DirectoryWatcherAPI;

type
  TDirectoryWatcher = class(TInterfacedObject, IDirectoryWatcher)
  protected
    FDirectory: String;
    FRecursively: Boolean;
    FEventHandler: TDirectoryEvent;
  public
    constructor Create(const Directory: String; const Recursively: Boolean; const EventHandler: TDirectoryEvent); 
    procedure Start; virtual; abstract;
  end;
  
implementation
 
constructor TDirectoryWatcher.Create(const Directory: String; const Recursively: Boolean; const EventHandler: TDirectoryEvent);
begin
  inherited Create;
  FDirectory := Directory;
  FRecursively := Recursively;
  FEventHandler := EventHandler;
end;

end.