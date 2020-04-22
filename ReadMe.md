# Steve's UE4 Scripts

## Subversion Repo Setup Script

This initialises the structure of a Subversion repository for UE4
usage. Run in the root of a new Subversion repository, whether you've created 
the UE4 project in there yet or not.

Usage:
```
    ue4-svn-setup.ps1 [[-src:]sourcefolder] [Options]

        -src         : Source folder (current folder if omitted)
                     : (should be root of trunk in new repo)
        -skipstructurecheck
                     : Skip the check that makes sure you're in trunk
        -overwriteprops
                     : Replace all properties instead of merging
                     : Will overwrite svn:ignore, svn:global-ignores, svn:auto-props
        -dryrun      : Don't perform any actual actions, just report on what you would do
        -help        : Print this help
```

### What it does

1. **Ignore unnecessary folders**

   It ignores folders in the root we don't need in Subversion:

   * .vs
   * Binaries
   * Build
   * DerivedDataCache
   * Intermediate
   * Saved

   It sets the `svn:ignore` property in the root folder to do this. It will merge
   with the contents of any existing property by default. `svn:ignore` is
   not set recursively and does not get inherited (despite what TortoiseSVN 
   gives the impression of).

1. **Sets binary files to needs-lock**

   By setting the `svn:auto-props` value for common binary types tracked in the
   repo such as .uasset and .umap, it enforces locking on those files, 
   triggering UE4 to give you check out prompts when you edit those files.

   This property is set on the root folder and is inherited throughout the tree.

1. **Creates folder structure**

   Subversion, and particularly TortoiseSVN has a "quirk" whereby inherited
   properties are not respected for files inside a folder that isn't added to
   SVN yet. This means that if you rely on `svn:global-ignores` being inherited
   from a parent, a file inside a new folder that *should* be ignored is still
   shown in the Add/Commit TSVN dialog, until its parent folder is added, at 
   which point it is hidden. 

   I maintain this is *extremely* dumb behaviour because you can easily add
   files that should be ignored by accident, unless you manually add the folder 
   first. However a big TSVN thread froma few years back has defended this
   bizarre approach as "by design". So to mitigate this, I pre-create the
   majority of our preferred folder structure ahead of time.

   Our preferred **workflow** is:

   1. All content creation tool files in `$REPO/MediaSrc` (subfolders by type)
      * These are typically in formats UE4 doesn't read directly, so outside `Content`
      * These files are tracked in SVN
   1. When exporting, place output (`FBX`, `PNG`, `WAV` etc) in `$REPO/Content` (and subfolders)
      * These files are *ignored* in SVN because they are derived data
      * UE4 imports them to a `.uasset` which contains all their contents anyway
   1. All `.uasset` post-imported content in `$REPO/Content` is tracked in SVN (binary)
     
   So the tool pre-creates `MediaSrc`, `Content` and subfolders (if they don't already
   exist), and add them to Subversion ahead of time to head off as many quirks
   as possible.

1. **Ignore derived export data in Content folder**

   As discussed in the workflow section above, exported files like `PNG` and `FBX`
   are not committed because they're duplicated data (source is in Maya/Blender/Photoshop files in `MediaSrc`, game-ready data is in `.uasset` files in `Content`). So we want
   to ignore them underneath `Content`.

   The `svn:ignore` property isn't helpful because it isn't inherited by subfolders, 
   and if you set it recursively it only applies to folders that already exist.
   Although we've tried to help by creating most of the structure up-front, we
   don't want to preclude creating new folders, and don't want everyone who
   does so to have to remember to set the `svn:ignore` up.

   So instead we use `svn:global-ignores`, a newer property that is inherited
   by children (although as noted above it behaves a little oddly before you add
   folders to SVN, but at least you don't have to set the property again). Any
   `PNG`, `FBX` files you export into `Content` for import will be ignored, and
   you can just commit the `.uasset` files, and the original sources in `MediaSrc`.
   The export files can be considered temporary.


   > We set `svn:global-ignores` for all the common intermediate formats *only*
   > on the `Content` folder. This is so that if, for some reason, you don't have
   > a typical content creator file for an asset and for some reason you want to 
   > store the `PNG` or `FBX` for it manually (instead of just the `.uasset`, which is all
   > the game needs), you can put those files in `MediaSrc` if you want, and copy
   > them to `Content` for importing as a substitute for the normal export workflow.
   > 
   > In practice I don't think you need to do this, because you can export `.uasset`
   > files anyway. Probably better to just put orphaned files like this directly in 
   > `Content` and only commit the post-import `.uasset`. But the option is there.



