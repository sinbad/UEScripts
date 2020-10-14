# Packaging Script

The `ue4-package.ps1` script builds, cooks and packages your game into a folder, 
much like using "File > Package Project" in the UE editor. However, it offers a 
number of other features.

This script operates based on a `packageconfig.json` file which must be present
in the root of your UE4 project. Please see the [Package Config File docs](PackageConfig.md)
for a full description of this file.

```
  ue4-package.ps1 [-src:sourcefolder] [-major|-minor|-patch|-hotfix] [-keepversion] [-force] [-variant=VariantName] [-test] [-dryrun]

  -src          : Source folder (current folder if omitted), must contain packageconfig.json
  -major        : Increment major version i.e. [x++].0.0.0
  -minor        : Increment minor version i.e. x.[x++].0.0
  -patch        : Increment patch version i.e. x.x.[x++].0 (default)
  -hotfix       : Increment hotfix version i.e. x.x.x.[x++]
  -keepversion  : Keep current version number, doesn't tag unless -forcetag
  -forcetag     : Move any existing version tag
  -variants Name1,Name2,Name3
                : Build only named variants instead of DefaultVariants from packageconfig.json
  -test         : Testing mode, separate builds, allow dirty working copy
  -browse       : After packaging, browse the output folder
  -dryrun       : Don't perform any actual actions, just report on what you would do
  -help         : Print this help

Environment Variables:
  UE4INSTALL   : Use a specific UE4 install.
               : Default is to find one based on project version, under UE4ROOT
  UE4ROOT      : Parent folder of all binary UE4 installs (detects version).
               : Default C:\Program Files\Epic Games
```

## What the Script Does

### 1. Check Working Copy

If you're using Git, as a safety check the script doesn't allow you to package 
builds from a working copy with uncommitted changes. This ensures that your builds
are always from a known version. 

### 2. Locate UE Install

The script can locate your UE4 install automatically. You may need to customise
this on non-Windows platforms or if you use a source build. 

See [How Scripts Locate the UE4 Install](UEInstall.md) for more details.

### 3. Close the UE Editor

If you have this project open in UE, the script will close the editor. This is
to ensure that it won't interfere with any build actions.

### 4. Increment Project Version

The version number of the project will be increased automatically, by default
as a "patch" release (meaning the 3rd number in the version string). As you 
can see, you can supply arguments `-major`, `-minor` or `-hotfix` instead to 
increment a different part of the version number. 

This will edit the `DefaultGame.ini` file and replace the `ProjectVersion` 
setting. This change will be committed automatically before the build if you're using Git.  

If you don't want to change the version number, you can provide `-keepversion` on
the command line instead.

### 5. Tags Git Repository

If you're using Git and the version number was incremented, the repository will
be tagged with the new version number.

### 6. Cook Maps

Based on your settings in [packageconfig.json](PackageConfig.md), the tools knows
which maps to cook into your packages. You can tell it to cook all of them automatically,
only a specific list, or all *excluding* a chosen few.

### 7. Package Variants

Rather than building / packaging just a single way, `ue4-package.ps1` supports
packaging multiple variants of your project. The variations can be:

* **Platform**: lets you build for Windows, Linux, Mac etc
* **Build Configuration**: so you can build a private version as Development, public version as Shipping for example
* **Build Arguments**: If you want to toggle on/off compiled-in features that are triggered by build arguments, you can add them for different variants
* **Release Destinations**: If you have one build for Itch, and a different one for Steam etc
* **Cultures**: For if you want to include specific cultures in a build

Variants are defined in [packageconfig.json](PackageConfig.md) in the root of 
your project. You can either specify which variants you want to build on the command line,
or you can just use the defaults as defined in your config.

### 8. Unique Package Folder

The destination of the package operation is generated from a combination of:

* The `OutputDir` setting in your [packageconfig.json](PackageConfig.md)
* The version number
* The variant name

Therefore if you're building variant "PublicSteamWin64" at version 1.1.2.0, the
package output will be in `$OutputDir/1.1.2.0/PublicSteamWin64/`

### 9. Optionally Zip Packaged Build

If you've enabled the `Zip` option for a given variant in [packageconfig.json](PackageConfig.md),
the package output folder will also be zipped up, into the `ZipDir` directory 
as given in that same config file.

The files are named `ProjectName_Version_Variant[_PlatformType].zip`, e.g. 
`MyGame_1.1.2.0_PublicSteamWin64.zip`. 

> We zip the contents of the *subfolder* of the package output, e.g. `WindowsNoEditor`,
so that the root of the zip is your game executable.

> The `_PlatformType` suffix is usually omitted; it will only be there if there is
more than one subfolder in the package folder, which is only the case when you
build a dedicated client & server. In that case there will be separate zips for
each, e.g. `MyGame_1.1.2.0_PublicSteamWin64_WindowsClient.zip` and `MyGame_1.1.2.0_PublicSteamWin64_WindowsServer.zip`

### 10. Optionally Browse Packaged Output

If you supply the optional argument `-browse`, your file manager will be asked to
open the folder containing the newly packaged output, if it completed successfully.