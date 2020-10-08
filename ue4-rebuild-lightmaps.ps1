# Lightmap rebuild helper
[CmdletBinding()] # Fail on unknown args
param (
    # Optional source folder, assumed current folder
    [string]$src,
    # quality level (Preview, Medium, High, Production), default = Production
    [string]$quality,
    # Explicit list of maps, if not supplied will use cooked maps in packageconfig.json
    [array]$maps,
    # Dry-run; does nothing but report what *would* have happened
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\packageconfig.ps1
. $PSScriptRoot\inc\projectversion.ps1
. $PSScriptRoot\inc\uproject.ps1
. $PSScriptRoot\inc\ueinstall.ps1
. $PSScriptRoot\inc\filetools.ps1

# Include Git tools locking
. $PSScriptRoot\GitScripts\inc\locking.ps1

function Write-Usage {
    Write-Output "Steve's UE4 lightmap rebuilding tool"
    Write-Output "Usage:"
    Write-Output "  ue4-rebuild-lightmaps.ps1 [-src:sourcefolder] [-quality:(preview|medium|high|production)]  [-maps Map1,Map2,Map3] [-dryrun]"
    Write-Output " "
    Write-Output "  -src          : Source folder (current folder if omitted)"
    Write-Output "  -quality      : Lightmap quality, preview/medium/high/production"
    Write-Output "                :   (Default: production)"
    Write-Output "  -maps         : List of maps to rebuild. If omitted, will derive which ones to"
    Write-Output "                  rebuild based on cooked maps in packageconfig.json"
    Write-Output "  -dryrun       : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help         : Print this help"
    Write-Output " "
    Write-Output "Environment Variables:"
    Write-Output "  UE4INSTALL   : Use a specific UE4 install."
    Write-Output "               : Default is to find one based on project version, under UE4ROOT"
    Write-Output "  UE4ROOT      : Parent folder of all binary UE4 installs (detects version). "
    Write-Output "               : Default C:\Program Files\Epic Games"
    Write-Output " "
}

if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}

$ErrorActionPreference = "Stop"

if ($help) {
    Write-Usage
    Exit 0
}

# Detect Git
if ($src -ne ".") { Push-Location $src }
$isGit = Test-Path ".git"
if ($src -ne ".") { Pop-Location }

Write-Output "~-~-~ UE4 Lightmap Rebuild Start ~-~-~"

try {
    $config = Read-Package-Config -srcfolder:$src
    $projfile = Get-Uproject-Filename -srcfolder:$src -config:$config
    $proj = Read-Uproject $projfile
    $ueVersion = Get-UE-Version $proj
    $ueinstall = Get-UE-Install $ueVersion

    if ($maps) {
        # Explicit list of maps provided on command line
        $foundmaps = Find-File-Set -startDir:$(Join-Path $src "Content") -pattern:*.umap -includeByDefault:$false -includeBaseNames:$maps

        if ($mapsToRebuild.Count -ne $maps.Count) {
            Write-Warning "Ignoring missing map(s): $($maps | Where-Object { $_ -notin $mapsToRebuild })"
        }
    } else {
        # Derive maps from cook settings
        $foundmaps = Find-Files -startDir:$(Join-Path $src "Content") -pattern:*.umap -includeByDefault:$config.CookAllMaps -includeBaseNames:$config.MapsIncluded -excludeBaseNames:$config.MapsExcluded
    }

    if ($foundmaps.BaseNames.Count -eq 0) {
        throw "No maps found to rebuild"
    }

    if (-not $quality) {
        $quality = "Production"
    }
    if ($quality -notin @("Preview", "Medium", "High", "Production")) {
        throw "Invalid quality level: $quality"
    }

    Write-Output ""
    Write-Output "Project File : $projfile"
    Write-Output "UE Version   : $ueVersion"
    Write-Output "UE Install   : $ueinstall"
    Write-Output ""
    Write-Output "Maps         : $($foundmaps.BaseNames)"
    Write-Output "Quality      : $quality"
    Write-Output ""

    # lock map files if read-only
    if ($isGit -and -not $dryrun) {
        if ($src -ne ".") { Push-Location $src }

        foreach ($mapfullname in $foundmaps.FullNames) {
            $relativepath = Resolve-Path $mapfullname -Relative
            Lock-If-Required $relativepath
            Lock-If-Required $($relativepath -replace ".uasset","_BuiltData.uasset")
        }
        if ($src -ne ".") { Pop-Location }
    }

    $argList = [System.Collections.ArrayList]@()
    $argList.Add("`"$projfile`"") > $null
    $argList.Add("-run=ResavePackages") > $null
    $argList.Add("-buildtexturestreaming") > $null
    $argList.Add("-buildlighting") > $null
    $argList.Add("-buildreflectioncaptures") > $null
    $argList.Add("-MapsOnly") > $null
    $argList.Add("-ProjectOnly") > $null
    $argList.Add("-AllowCommandletRendering") > $null
    $argList.Add("-SkipSkinVerify") > $null
    $argList.Add("-Quality=$quality") > $null
    $argList.Add("-Map=$($foundmaps.BaseNames -join "+")") > $null   

    $ueEditorCmd = Join-Path $ueinstall "Engine/Binaries/Win64/UE4Editor-Cmd$exeSuffix"

    if ($dryrun) {
        Write-Output "Would have run:"
        Write-Output "> $ueEditorCmd $($argList -join " ")"

    } else {
        Write-Output "Starting lighting build; see Swarm Agent for full progress monitoring..."
        $proc = Start-Process $ueEditorCmd $argList -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            throw "Lightmap build failed!"
        }

    }

} catch {
    Write-Output $_.Exception.Message
    Write-Output "~-~-~ UE4 Lightmap Rebuild FAILED ~-~-~"
    Exit 9

}


Write-Output "~-~-~ UE4 Lightmap Rebuild OK ~-~-~"
Write-Output "Reminder: You may need to commit and unlock map files"
