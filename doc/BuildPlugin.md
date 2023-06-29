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
  -allversions  : Build for all supported UE versions, not just the current one"
                : (specified in pluginconfig.json, only works with lancher-installed UE)"
  -uever:5.x.x  : Build for a specific UE version, not the current one (launcher only)"
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

    "EngineVersions":
    [
        "5.1.0",
        "5.2.0"
    ]


}
```

Only `BuildDir` is required.

The `-allversions` option only works with Launcher installed engines,
since the path is derived from UEROOT. If using non-Launcher engines, or you
need to change some other environmental options per version (e.g. setting
`LINUX_MULTIARCH_ROOT` environment var), then you're recommended to instead
use the `-uever:` option to build one version at a time, and set the environment
(including `UEINSTALL`) specifically for each version.

This script will, however, handle changing the EngineVersion in the .uplugin
during the build, and resetting it afterwards.