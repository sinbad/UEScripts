# LEGACY: Subversion Information (ignore below if using Git)

## Steps to create a new SVN repo for a UE4 project

1. Create new repo on your Subversion server, note the URL e.g. https://foo/bar
1. Run `ue4-svn-create.ps1 [URL]` in the parent folder you want your project to live
1. This will result in a subfolder called "bar" by default due to URL suffix
   > See [creation script usage](#subversion-repo-creation-script) to specify a different destination path
1. After it's finished the script will have created the trunk/branches/tags folders for you,
  and then checked out the trunk for you into "bar"
1. You then need to copy the contents of your UE4 project into this folder
    > (UE4 doesn't let you create projects in non-empty folders so if you haven't 
     created a project yet, create it somewhere else then move the contents)

## Updating an existing UE4 project

If you already have a UE4 project in Subversion, you can instead just run the
[in-place setup script](#subversion-repo-setup-script) instead to configure it
for the workflow discussed above. You'll just need to commit the changes
after the script has completed.

## What these scripts do

### Creation Script

1. **Creates trunk / branches / tags folders**

    If they're missing, the script creates them and commits to the root.

1. **Checks out trunk**

    This will become your working folder. 

1. **Runs the setup script**

   Performs all the steps from the [setup script](#-setup-script) below.
   It then commits all these changes so the working copy is ready to use.

### Setup Script

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
   repo such as `.uasset` and `.umap`, it enforces locking on those files, 
   triggering UE4 to give you check out prompts when you edit them.

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
   first. However a big TSVN thread from a few years back has defended this
   bizarre approach as "by design". So to mitigate this, I pre-create the
   majority of our preferred folder structure ahead of time.

   Our preferred **workflow** is:

   1. All content creation tool files in `$REPO/MediaSrc` (subfolders by type)
      * These are typically in formats that UE4 might not read directly, so outside `Content`
      * These files are *tracked* in SVN
   1. When exporting, place output (`FBX`, `PNG`, `WAV` etc) in `$REPO/Content` (and subfolders)
      * These files are *ignored* in SVN because they are derived data
      * UE4 imports them to a `.uasset` which contains all their contents anyway
   1. All `.uasset` post-imported content in `$REPO/Content` is *tracked* in SVN (binary)
     
   So the tool pre-creates `MediaSrc`, `Content` and subfolders (if they don't already
   exist), and adds them to Subversion ahead of time to head off as many quirks
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



## Script Reference

### Repo Creation Script

This constructs the entirety of the starting repository from a Subversion URL
(which should contain an empty repository, or at most empty trunk/branches/tags
subfolders).

Usage:
```
      ue4-svn-create.ps1 [-urn:]svnurl [[-path:]checkoutpath] [Options]
     
      -url         : Subversion URL; the ROOT path (should be empty)
      -path        : Checkout path; if omitted append last part of URL to current dir
      -help        : Print this help
```

It calls the [setup script below](#subversion-repo-setup-script), 
plus creating the trunk/branches/tags structure, and checking out trunk for you.
It also commits all the changes so your repo is ready to go.

Unreal doesn't let you create a new project inside a directory with contents,
so create your new project elsewhere then copy it into this new trunk checkout.
Unfortunately there's no way to avoid this because we need folders to exist
to set SVN properties on them.

### Repo Setup Script

This is a second-level script to intialise the structure of an existing Subversion 
trunk checkout for UE4. Run in the root of that trunk checkout - it will work
for existing UE4 folders or blank repositories.

None of the changes are committed so you can review them.

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

