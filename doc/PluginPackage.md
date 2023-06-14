# Packaging a Plugin for the Marketplace

To distribute a plugin on the marketplace, you need to zip it up and make sure
you only include approved files. The `ue-plugin-package.ps1` script is here
to make that job easier.

> Note: unless you use the `-keepversion`, the script will update your .uplugin
> file to record the new version number and potentially set Installed=true.
> Unfortunately the first time, this will probably mess with indents.

```sh
Usage:
  ue-plugin-package.ps1 [-src:sourcefolder] [-major|-minor|-patch|-hotfix] [options...]

  -src          : Source folder (current folder if omitted), must contain pluginconfig.json
  -major        : Increment major version i.e. [x++].0.0.0
  -minor        : Increment minor version i.e. x.[x++].0.0
  -patch        : Increment patch version i.e. x.x.[x++].0 (default)
  -hotfix       : Increment hotfix version i.e. x.x.x.[x++]
  -keepversion  : Keep current version number, doesn't tag unless -forcetag
  -forcetag     : Move any existing version tag
  -notag        : Don't tag even if updating version
  -test         : Testing mode, separate builds, allow dirty working copy
  -browse       : After packaging, browse the output folder
  -dryrun       : Don't perform any actual actions, just report on what you would do
  -help         : Print this help
```

This script operates based on a `pluginconfig.json` file which must be present
in the root of your plugin, next to the .uplugin file. The options are:

```json
{
    "OutputDir": "C:\\Users\\Steve\\MarketplaceBuilds",
    "PluginFile": "OptionalPluginFilenameWillDetectInDirOtherwise.uplugin"
}