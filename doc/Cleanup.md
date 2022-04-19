# Cleanup tool

Mostly this script cleans up Hot Reload DLLs that often get left over. It used
to also call `git lfs prune` but has stopped doing that for now because 
of a previous bug in Git LFS which would delete stashed LFS files.

I don't use this script very much any more because I'm using Live Coding now.
The script also cleans up Live Coding patches but there's fewer of those.

```
  ue4-cleanup.ps1 [[-src:]sourcefolder] [Options]

  -src         : Source folder (current folder if omitted)
               : (should be root of project)
  -nocloseeditor : Don't close Unreal editor (this will prevent DLL cleanup)
  -lfsprune    : Call 'git lfs prune' to delete old LFS files as well
  -dryrun      : Don't perform any actual actions, just report on what you would do
  -help        : Print this help
```

