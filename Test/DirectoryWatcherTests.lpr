program DirectoryWatcherTests;

uses
  {$IFNDEF WINDOWS} cThreads, {$ENDIF}
  Classes, ConsoleTestRunner, TestDirectoryWatcher;

{$MACRO ON}
var
  Application: TTestRunner;

begin
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Run;
  Application.Free;
end.