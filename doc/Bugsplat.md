# Bugsplat Symbol Uploader

The `ue-bugsplat-upload.ps1` script uploads debug symbols from a previously [packaged release](Package.md) to 
[Bugsplat](https://bugsplat.com).


```
Steve's Unreal Bugsplat Symbol Upload tool
Usage:
  ue-bugsplat-upload.ps1 [-src:sourcefolder] [-variants=VariantName] [-test] [-dryrun]

  -version:ver  : Version to upload; must have been packaged already (or use -latest)
  -latest       : Instead of an explicit version, upload one identified in project settings
  -src          : Source folder (current folder if omitted), must contain packageconfig.json
  -variants Name1,Name2,Name3
                : Upload only named variants instead of DefaultVariants from packageconfig.json
  -dryrun       : Don't perform any actual actions, just report on what you would do
  -help         : Print this help

Environment Variables:
  UEINSTALL   : Use a specific Unreal install.
              : Default is to find one based on project version, under UEROOT
  UEROOT      : Parent folder of all binary Unreal installs (detects version).
              : Default C:\Program Files\Epic Games

  SYMBOL_UPLOAD_CLIENT_ID     : OAuth client ID defined in Bugsplat
  SYMBOL_UPLOAD_CLIENT_SECRET : OAuth secret for Bugsplat
```

In order to use this tool, you must have already done the following:

1. Signed up for [Bugsplat](https://bugsplat.com). The free tier is quite generous, unless you go big you should be fine.
1. Generated an OAuth ID/Secret and set these in environment variables as `SYMBOL_UPLOAD_CLIENT_ID` and `SYMBOL_UPLOAD_CLIENT_SECRET`
1. Downloaded `symbol-update-windows.exe` from [Bugsplat's GitHub](https://github.com/BugSplat-Git/symbol-upload/releases) and added it to your `PATH`
1. Set `BugsplatDatabase` and `BugsplatApp` in your your [packageconfig.json](PackageConfig.md)

> You MUST [package the release](Package.md) *after* making the changes to your [packageconfig.json](PackageConfig.md),
> because that will create an extra DefaultEngine.ini file in your packaged release, including the
> crash reporter URL generated from this information (and the version number).

Once you've done this setup and packaged a release, this script will upload the related debug symbols, tagged with the
correct version number, to Bugsplat. 

