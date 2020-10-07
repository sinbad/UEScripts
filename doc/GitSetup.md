# Git Setup

We use Git LFS with Unreal, including [Git LFS Locking](https://github.com/git-lfs/git-lfs/wiki/File-Locking) which is now supported by 
most Git hosts, including self-hosted options like [Gitea](https://gitea.io/). Locking
is important because Unreal uses a lot of binary `.uasset` files which are not mergeable.

To make best use of git, LFS and locking, you really want to be using the 
[Git LFS 2 plugin](https://github.com/SRombauts/UE4GitPlugin) for the Unreal Editor. I
also have a [fork of this plugin](https://github.com/sinbad/UE4GitPlugin) with some 
improvements which haven't been merged yet. I'm still making improvements so
you might want to keep an eye on that.

We use a this content workflow in our UE game repositories:

1. All content creation files in `$REPO/MediaSrc` (subfolders by type)
    * These are typically in formats e.g. Blender that UE4 doesn't read directly, so outside `Content`
    * These files are added to Git
    * They are also tracked as Git LFS files
    * They are NOT marked as lockable, simply because the tooling for managing locking
      isn't very good outside of Unreal right now
1. When exporting, output (`FBX`, `PNG`, `WAV` etc) goes in `$REPO/Content` (and subfolders)
    * These files are *ignored* in Git because they are derived data
    * UE4 imports them to a `.uasset` which contains all their contents anyway
1. Imported content becomes `.uasset` in `$REPO/Content`
    * These files are added to Git
    * They are also tracked as Git LFS files
    * These are also marked as *lockable* in Git LFS

Together the script below configures all of this automatically.

## The script

You run the script from a Powershell prompt, in the root of your UE4 project.

```
ue4-git-setup.ps1 [[-src:]sourcefolder] [Options]

-src         : Source folder (current folder if omitted)
             : (should be root of your UE4 project)
-dryrun      : Don't perform any actual actions, just report on what you would do
-help        : Print this help
```

See the notes below for some practical details of running it.

## Notes

1. The script works for projects with no git repo yet, or those with an existing git repo
1. For existing repos, it's better if you have not committed any large files to Git yet
   * If you have, it is *highly recommended* you use `git lfs migrate` to re-write your repository history to be LFS compatible
   * `git lfs migrate import --everything --include="*.uasset,*.umap,<others>"`
   * This repo will need to be re-cloned by everyone but it's MUCH cleaner than changing to LFS mid-history
1. Make a note of any custom .gitignore entries you have, the script will replace it
1. Run `ue4-git-setup.ps1` in the root project folder
1. Add back any specialised .gitignores we didn't cover (might not need any)
1. Push ALL BRANCHES of this new repo to the host of your choice

