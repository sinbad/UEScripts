# Packaging a Plugin for the Marketplace

To distribute a plugin on the marketplace, you need to zip it up and make sure
you only include approved files. The `ue-plugin-package.ps1` script is here
to make that job easier.

> **Note:** This script will update your .uplugin file to record the new version number,
> and manipulate EngineVersion for each build. Its state will be restored afterwards
> (apart from the version number). 
>
> Unfortunately the first time, this will probably mess with indenting because
> of a difference of opinion between JSON libraries. But it's harmless.

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
    "PluginFile": "OptionalPluginFilenameWillDetectInDirOtherwise.uplugin",
    "EngineVersions":
    [
        "5.0.0",
        "5.1.0",
        "5.2.0"
    ]    
}
```

`OutputDir` and `EngineVersions` are required.

## Engine Versions

When submitting code plugins to the Marketplace, you're only allowed to include
a single supported `EngineVersion` in each version you upload. Even though you 
don't submit built binaries to the Marketplace, the publisher portal requires
that the .uplugin has a single `EngineVersion` entry.

Therefore to support multiple engine versions, you have to upload several essentially
identical source archives, with each one having a different `EngineVersion` specified
in the .uplugin.

This script helps you do that; for each entry in `EngineVersions` in the `pluginconfig.json`,
a separate zip archive is generated, with the correct version set in the .uplugin.

> It seems you should always use ".0" as the 3rd version digit.

## Excluding Files

By default, the plugin packaging process automatically excludes common
files and directories that shouldn't be there:

* ./.git/
* ./.git*
* ./Binaries/
* ./Intermediate/
* ./Saved/
* ./pluginconfig.json

If you'd like to exclude other things, create a file called `packageexclusions.txt`
in the root of the plugin, listing files/folders you want to exclude (one per line).
