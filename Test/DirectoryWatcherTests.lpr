program DirectoryWatcherTests;

uses
  // heaptrc,
  Classes, ConsoleTestRunner, TestDirectoryWatcher;

var
  Application: TTestRunner;

begin
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'FPCUnit Console test runner';
  Application.Run;
  Application.Free;
end.