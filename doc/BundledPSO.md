# Creating / Updating Bundled PSO Caches

The `ue-psobundle.ps1` script automates the process described in the 
[UE bundled PSO docs](https://dev.epicgames.com/documentation/unreal-engine/manually-creating-bundled-pso-caches-in-unreal-engine). 

The idea is to reduce or remove shader stutters in modern graphics APIs by recording what Pipeline State Objects (PSOs)
are used in a game session, and then telling the engine about them at startup so it can begin compiling those shaders
immediately, and not do it on demand with all the stuttering that results in.

> Note: Currently only DirectX 12 is supported. Patches welcome for Vulkan/Metal, it's probably just some file name changes
> but I'm not testing with those environments yet. DirectX 11 doesn't have PSOs so doesn't need this (it does get stutters, but less so than Dx12)

This script uses the `PSOCacheDir` option in `packageconfig.json`, please see the [Package Config File docs](PackageConfig.md)
for a full description of this file.

```
Usage:
  ue-psobundle.ps1 [[-src:]sourcefolder] [Options] -out:PackageDir

  -src         : Source folder (current folder if omitted)
               : (should be root of project)
  -out         : Required param, where to put the packaged build we use
  -clean       : Delete all data and gather PSOs from scratch instead of incremental
  -variants Name1,Name2,Name3
                : Build only named variants instead of DefaultVariants from packageconfig.json
  -nocloseeditor : Don't close Unreal editor (this will prevent DLL cleanup)
  -dryrun      : Don't perform any actual actions, just report on what you would do
  -help        : Print this help

Environment Variables:
  UEINSTALL   : Use a specific Unreal install.
              : Default is to find one based on project version, under UEROOT
  UEROOT      : Parent folder of all binary Unreal installs (detects version).
              : Default C:\Program Files\Epic Games
```

## What the Script Does

1. Generates stable shader keys (.shk)
2. Packages your game into the `-out` dir - this can be a temp folder, you don't need it afterwards
3. Runs your game with the `-logPSO` option to record PSOs being built (shaders being compiled)
4. Collects all that data and packs it into `.spc` files in yor project build dir for use in the next package created

In stage 3 you should run around in your game trying to see as much as you can, so the PSOs in use get recorded. Some
people make a "zoo" level with everything in it to make this easier, but since the process is cumulative you can just
do bits at a time if you want.

The end result is `.spc` files in your project Build/Platform/PipelineCaches folder, which on next
cook/package will include that list of PSOs/shaders in your next game build, and you can use `FShaderPipelineCache::NumPrecompilesRemaining()`
to determine the progress of the typical "Recompiling shaders" process at startup.

You can run this script multiple times during development and it will add more `.spc` files to your project, the
process is incremental. At points you'll probably want to use the `-clean` option to delete all the old files
and start from scratch.

You might want to commit `Build/Platform/PipelineCaches/*.spc` to source control, so that your build process can pick
them up, they're actually not that large.

## Testing the result

To test that this has done what you hope:

1. [Package the game](Package.md) again
2. Launch the game with the `-clearPSODriverCache` option to force all PSOs to be rebuilt
3. Use `FShaderPipelineCache::NumPrecompilesRemaining()` to know when shader precompilation is done
