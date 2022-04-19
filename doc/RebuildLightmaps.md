# Rebuilding Lightmaps

This script is a more convenient alternative to calling `RunUAT RebuildLightmaps`, which 
has the downside of being unnecessarily dependent on Perforce.

This script is compatible with Git (if you're using it), and specifically copes
with Git LFS file locking. When building lighting the `.umap` needs to be locked 
for writing, this script will do that if necessary. The RunUAT version fails if
you don't have Perforce even if you've already locked the file in LFS! Very silly.

This script uses the [packaging configuration file](./Package.md) and can 
automatically determine which maps to rebuild if you want, or you can 
explicitly list them as arguments: 

```
  ue-rebuild-lightmaps.ps1 [-src:sourcefolder] [-quality:(preview|medium|high|production)]  [-maps Map1,Map2,Map3] [-dryrun]

  -src          : Source folder (current folder if omitted)
  -quality      : Lightmap quality, preview/medium/high/production
                :   (Default: production)
  -maps         : List of maps to rebuild. If omitted, will derive which ones to
                  rebuild based on cooked maps in packageconfig.json
  -dryrun       : Don't perform any actual actions, just report on what you would do
  -help         : Print this help

Environment Variables:
  UEINSTALL   : Use a specific Unreal install.
              : Default is to find one based on project version, under UEROOT
  UEROOT      : Parent folder of all binary Unreal installs (detects version).
              : Default C:\Program Files\Epic Games
```