# Building Plugins

If you want to build a plugin so that you can test it locally as if it was a 
Marketplace plugin (before you [package it](PluginPackage.md)), the 
`ue-build-plugin.ps1` script can help make it easier.

The plugin will be built for the current platform only, using the engine version
specified in the .uplugin file.


```
Usage:
  ue-build-plugin.ps1 [[-src:]sourcefolder] [Options]

  -src          : Source folder (current folder if omitted)
                : (should be root of project)
  -allplatforms : Build for all platforms, not just the current one
  -dryrun       : Don't perform any actual actions, just report on what you would do
  -help         : Print this help

Environment Variables:
  UEINSTALL   : Use a specific Unreal install.
              : Default is to find one based on project version, under UEROOT
  UEROOT      : Parent folder of all binary Unreal installs (detects version).
              : Default C:\Program Files\Epic Games
```

This script operates based on a `pluginconfig.json` file which must be present
in the root of your plugin, next to the .uplugin file. The options are:

```json
{
    "PackageDir": "C:\\Users\\Steve\\Marketplace",
    "BuildDir": "C:\\Users\\Steve\\Builds\\MyPlugin",
    "PluginFile": "OptionalPluginFilenameWillDetectInDirOtherwise.uplugin",
}
```

Only `BuildDir` is required.