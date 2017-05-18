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
    function GetDirectory: String;
    function GetWatchSubdirectories: Boolean;
  end;
  
implementation

uses
  SysUtils;
 
constructor TDirectoryWatcher.Create(const Directory: String; const Recursively: Boolean; const EventHandler: TDirectoryEvent);
begin
  inherited Create;
  FDirectory := IncludeTrailingPathDelimiter(Directory);
  FRecursively := Recursively;
  FEventHandler := EventHandler;
end;

function TDirectoryWatcher.GetDirectory: String;
begin
  Result := FDirectory;
end;

function TDirectoryWatcher.GetWatchSubdirectories: Boolean;
begin
  Result := FRecursively;
end;

end.