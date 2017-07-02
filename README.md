# DirectoryWatcher
Watch changes in directories on different platforms.

This is an abstraction layer for
  - `ReadDirectoryChangesW` on **Windows**
  - `FSEvent` on **Mac OS**
  - `inotify` on **Linux**

## How to use
```Pascal
// Create new DirectoryWatcher
DirectoryWatcher := TDirectoryWatcherBuilder
                    .New
                    .WatchDirectory(FolderToWatch)
                    .Recursively(True)
                    .OnChangeTrigger(OnFileEvent)
                    .Build;

// Start watching in different thread
DirectoryWatcher.Start;

// Stop DirectoryWatcher
DirectoryWatcher := Nil;

// ...

procedure TDirectoryWatcherDemo.OnFileEvent(const FilePath: String; 
                                            const EventType: TDirectoryEventType);
var
  EventTypeString: String;
begin
  WriteLn('======NEW EVENT======');
  WriteLn('File: ' + FilePath);

  case EventType of
    detAdded: EventTypeString := 'ADDED';
    detRemoved: EventTypeString := 'REMOVED';
    detModified: EventTypeString := 'MODIFIED';
  end;

  WriteLn('Type: ' + EventTypeString);
end;  
```
