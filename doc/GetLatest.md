# Getting Latest for Artists

We've found it useful to provide a simple script which can be run on artists'
machines to get the latest from Git, and make sure all the C++ components are
built. 

It now also automatically calls `ue4-datasync.ps1 pull` if `UE4SYNCROOT` is defined
in the environment.

While the UE editor can sometimes do this successfully on startup as well,
it's just nicer to do it as part of the update process - the artist can then 
just double-click a shortcut on their desktop and let it run while getting
coffee or something.

The script also automatically closes the UE editor if it's open on the same
project to make sure the build is successful.

```
  ue4-get-latest.ps1 [[-src:]sourcefolder] [Options]

  -src         : Source folder (current folder if omitted)
               : (should be root of project)
  -nocloseeditor : Don't close UE4 editor (this will prevent DLL cleanup)
  -dryrun      : Don't perform any actual actions, just report on what you would do
  -help        : Print this help
```

