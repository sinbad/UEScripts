# Synchronising "BuiltData" Files Outside Git

## Why?

Unreal stores lighting and other built data for your maps in a separate file.
If your level is called "YourMap.umap", then lighting data will be saved in 
"YourMap_BuiltData.uasset".

This data is entirely derived from the .umap file, and is also very large. Given 
this, it's a prime candidate for exclusion from version control; there's no
need to fill up your repository with large data that can be rebuilt from the data
already tracked in it.

However, there's a problem with doing this:

1. Anyone else on the team won't see lighting you've built
1. Even if they take the time to rebuild lighting themselves, this process wants
   to alter the base .umap file as well, since there are cross-references

Most of the time you can get away with not including the BuiltData in the repository,
each person building lighting locally and deliberately NOT saving their map changes
when prompted. However, building the lighting gets more time consuming over time,
and remembering not to save is a pain. 

## Isn't there a standard solution?

The solution normally presented is to use Perforce, where you can tell Perforce
to only keep the latest version of a given pattern of file. In that scenario
BuiltData files are tracked in the repository and versions other than the latest
are just deleted.

Vanilla Git can't do this. Git LFS can, but only if you write some pruning code
specific to your LFS server. It's not ideal.

## My solution

My solution is to write a tool to make it easier to share BuiltData files 
as a side-channel to the Git LFS repository. You simply provide a file share
(ideally a network drive, or a synced folder like Google Drive / Dropbox if you
don't mind a little duplication) and use my script `ue-datasync.ps1` to 
sync lighting data between team members. 

Using Git LFS is a prerequisite, because it uses the OIDs from the .umap files
(which must be tracked in Git LFS) as a corresponding identifier to make sure
the matching version of the BuiltData is used. 

## Details

Note: this script will automatically close the Unreal editor if you have the
project open, in order to prevent accidental issues such as unsaved changes or
locked files. 

```
Usage:
  ue-datasync.ps1 [-mode:]<push|pull> [[-path:]syncpath] [Options]

  -mode        : Whether to push or pull the built data from your filesystem
  -root        : Root folder to sync files to/from. Project name will be appended to this path.
               : Can be blank if specified in UESYNCROOT
  -src         : Source folder (current folder if omitted)
               : (should be root of project)
  -prune       : Clean up versions of the data older than the latest
  -force       : Copy ALL BuiltData files regardless of size/timestamp checks
  -nocloseeditor : Don't close Unreal editor (this will prevent download of updated files)
  -dryrun      : Don't perform any actual actions, just report on what you would do
  -verbose     : Print more information
  -help        : Print this help

Environment Variables:
  UESYNCROOT  : Root path to sync data. Subfolders for each project name.
  UEINSTALL   : Use a specific Unreal install.
              : Default is to find one based on project version, under UEROOT
  UEROOT      : Parent folder of all binary Unreal installs (detects version).
              : Default C:\Program Files\Epic Games
```

You must tell the sync tool where the shared drive is, either using the `-root`
argument, or defining the `UESYNCROOT` environment variable. A project folder
will be added below that, based on the name of your .uproject file, so that
you can use the same root folder for multiple projects.

The tools works in "push" or "pull" mode, and processes all .umap files which
are tracked in Git LFS (others are ignored). It's worth explaining exactly
what happens in each mode.

### Push mode

> Example: `ue-datasync.ps1 push`
>
> Assuming you run this in your project root and have defined the environment variable UESYNCROOT

In push mode, you want to upload BuiltData files you've updated, probably because of a 
change to the .umap. You have to have committed your changes to the .umap first, 
the tool won't allow you to push changes if they're uncommitted (to avoid drifting changes).

For each umap file, the Git LFS OID (basically a SHA256 of the umap file) for your
current version is used to derive a version-specific filename, e.g. "YourMap_BuiltData_112233445567.uasset".
Your local copy of the BuiltData file will be copied to the shared drive with this
name (under the subfolder Project/ContentPath). If there's already a file named
this in the shared folder, and the size & date/timestamp match, then nothing will happen,
unless you use the `-force` argument.

Because you're not allowed to have local uncommitted changes to the umap files, 
and the BuiltData is tagged with the SHA of the umap, this means other people can
get a 'safe' copy of your current lighting build corresponding to the state of the
umap on this shared drive, without it being in the git repo.

### Pull mode

> Example: `ue-datasync.ps1 pull`
>
> Assuming you run this in your project root and have defined the environment variable UESYNCROOT

In pull mode, the script tries to find the BuiltData files corresponding to your
umap files on the shared drive. Again, you can't have any uncommitted changes to
umap files.

In the same way as push, the script uses the OID of the umap file to look up 
the versions on the shared drive. However, if a lighting build with that
OID doesn't exist, pull checks the git log and finds the latest lighting build 
available for that umap file. This is to deal with the case where changes have
been made to the umap file since the last lighting build, but the lighting build
is still OK to use (either the umap changes didn't affect lighting, or the 
differences are "good enough" for the moment). 

If an appropriate BuiltData file is found on the shared drive, and
you don't have a newer local version, then the BuiltData file is copied into
place in your local project folder. Next time you open the editor you'll 
have the lighting data that your team mate built.

## Pruning

By default, the different versions of BuiltData would build up on the shared
drive, one per OID of .umap file. To clean up and only keep the latest, 
add the `-prune` option (this isn't enabled by default because destructive actions
should always be opt-in).

The prune routine looks at all your tracked .umap files, and then deletes any
files on the shared drive for this umap that have OIDs *other than* the current
version, and which have an older modification date (to prevent accidental deletion
of newer versions someone else has recently pushed after the version you're on).

Although you can provide `-prune` to any invocation of this script, I'd recommend
you only do it for the `push` variant.

## Automating this

You can use `ue-datasync.ps1` manually, calling it in `push` mode just after 
you push any map changes (assuming you've built the lighting), and in `pull` mode
on demand, as and when you know you want to pick up new lighting data that others
have built.

Alternatively you could add these commands to your git hooks, perhaps `pre-push`
and `post-checkout` for `push` and `pull` respectively. Given the lower frequency
of lighting build changes though, the manual approach is probably fine.