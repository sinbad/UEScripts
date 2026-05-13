[CmdletBinding()] # Fail on unknown args
param (
    [string]$src,
    [string]$out,
    [switch]$clean = $false,
    [switch]$d3d11 = $false,
    [switch]$nocloseeditor = $false,
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\packageconfig.ps1
. $PSScriptRoot\inc\projectversion.ps1
. $PSScriptRoot\inc\uproject.ps1
. $PSScriptRoot\inc\ueeditor.ps1
. $PSScriptRoot\inc\filetools.ps1

function Print-Usage {
    Write-Output "Steve's Unreal PSO Cache Tool"
    Write-Output "Usage:"
    Write-Output "  ue-psocache.ps1 [[-src:]sourcefolder] [Options] -out:PackageDir"
    Write-Output " "
    Write-Output "  -src         : Source folder (current folder if omitted)"
    Write-Output "               : (should be root of project)"
    Write-Output "  -out         : Required param, where to put the packaged build we use"
    Write-Output "  -clean       : Delete all data and gather PSOs from scratch instead of incremental"
    Write-Output "  -d3d11       : On Windows targets, record D3D11/SM5 instead of D3D12/SM6"
    Write-Output "  -variants Name1,Name2,Name3"
    Write-Output "                : Build only named variants instead of DefaultVariants from packageconfig.json"
    Write-Output "  -nocloseeditor : Don't close Unreal editor (this will prevent DLL cleanup)"
    Write-Output "  -dryrun      : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help        : Print this help"
    Write-Output " "
    Write-Output "Environment Variables:"
    Write-Output "  UEINSTALL   : Use a specific Unreal install."
    Write-Output "              : Default is to find one based on project version, under UEROOT"
    Write-Output "  UEROOT      : Parent folder of all binary Unreal installs (detects version). "
    Write-Output "              : Default C:\Program Files\Epic Games"
    Write-Output " "

}

if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}

$ErrorActionPreference = "Stop"

if ($out.Length -eq 0) {
    Write-Output "ERROR: Required argument '-out:PackageDir'"
    Print-Usage
    Exit 5
}



if ($help) {
    Print-Usage
    Exit 0
}

# Detect Git
if ($src -ne ".") { Push-Location $src }
$isGit = Test-Path ".git"
if ($src -ne ".") { Pop-Location }

Write-Output "~-~-~ Unreal PSO Cache Helper Start ~-~-~"

try {
    # Import config & project settings
    $config = Read-Package-Config -srcfolder:$src
    $projfile = Get-Uproject-Filename -srcfolder:$src -config:$config
    $proj = Read-Uproject $projfile
    $ueVersion = Get-UE-Version $proj
    $ueinstall = Get-UE-Install $ueVersion
    $projname = [System.IO.Path]::GetFileNameWithoutExtension($projfile)
    $projdir = [System.IO.Path]::GetDirectoryName($projfile)

    if ($config.PSOCacheDir.Length -eq 0)
    {
        throw "PSOCacheDir is empty in config, aborting"
    }


    Write-Output ""
    Write-Output "Project File    : $projfile"
    Write-Output "Project Name    : $projname"
    Write-Output "UE Version      : $ueVersion"
    Write-Output "UE Install      : $ueinstall"
    Write-Output "PackageDir      : $out"
    Write-Output "Clean Mode      : $clean"
    Write-Output "PSO Cache Dir   : $($config.PSOCacheDir)"
    Write-Output ""

    if (-not $dryrun)
    {
        Close-UE-Editor $projname $dryrun
    }

    $chosenVariantNames = $config.DefaultVariants
    if ($variants) {
        $chosenVariantNames = $variants
    }
    # TODO support overriding default variants with args
    $chosenVariants = $config.Variants | Where-Object { $chosenVariantNames -contains $_.Name }

    if ($chosenVariants.Count -ne $chosenVariantNames.Count) {
        $unmatchedVariants = $chosenVariantNames | Where-Object { $chosenVariants.Name -notcontains $_ } 
        Write-Warning "Unknown variant(s) ignored: $($unmatchedVariants -join ", ")"
    }

    # Make a project-specific subdir of PSO cache dir (could be shared)
    $projPSOcache = Join-Path $config.PSOCacheDir $projname
    if (-not $Dryrun) {
        New-Item -ItemType Directory $projPSOcache -Force > $null
    }

    if ($clean -and -not $dryrun) {
        # Delete everything in the PSO cache area
        Remove-Item "$projPSOcache\*.rec.upipelinecache" -Force
        Remove-Item "$projPSOcache\*.shk" -Force

        # Also delete our existing .spc files
        Remove-Item "Build\*\PipelineCaches\*.spc" -Force

    }

    # We package the game, which will generate the .shk files if needed
    ue-package.ps1 -nightly -test -out:$out -variants:$variants -dryrun:$dryrun -skipzip

    if ($isGit)
    {
        $buildID = $(git rev-parse --short HEAD)
    }
    else
    {
        $buildID = Get-Date -Format "yyyyMMdd"
    }

    # Now we run the project in record mode
    foreach ($var in $chosenVariants) 
    {
        # Only automate for Windows right now
        if ($var.Platform.StartsWith("Win"))
        {

            # -------------  RECORD --------------------------   

            # It's important that we process SM5 and SM6 files separately, hence the specific matching
            $shadermodel = "SM6"
            if ($d3d11) {
                $shadermodel = "SM5"
            }

            # Copy out the .shk files that were generated
            # e.g. Saved\Cooked\Windows\ProjectName\Metadata\PipelineCaches
            $shksrc = Join-Path $src "Saved" "Cooked" "Windows" $projname "Metadata" "PipelineCaches"
                if ($dryrun) {
                Write-Output ""
                Write-Output "Would have copied ${shksrc}/*PCD3D_$($shadermodel)*.shk to $projPSOcache"
                Write-Output ""
            } else {
                Get-ChildItem -Path $shksrc -Filter "*PCD3D_$($shadermodel)*.shk" | Copy-Item -Destination $projPSOcache
            }


            $gamerootdir = Join-Path $out "$($var.Name)-nightly-test" "Windows"
            $game =  Join-Path $gamerootdir "${projname}.exe"

            # Run default
            $argList = [System.Collections.ArrayList]@()
            # record PSOs
            $argList.Add("-logPSO") > $null
            # discard all previously compiled shaders so we record everything
            $argList.Add("-clearPSODriverCache") > $null
            if ($d3d11) {
                $argList.Add("-d3d11") > $null
            }

            if ($dryrun) {
                Write-Output ""
                Write-Output "Would have run:"
                Write-Output "> $game $($argList -join " ")"
                Write-Output ""

            } else {            
                Write-Output "~-~-~ Launching Game To Record PSO Usage ~-~-~"

                $proc = Start-Process $game $argList -Wait -PassThru -NoNewWindow
                if ($proc.ExitCode -ne 0) {
                    throw "Running game failed!"
                }
                Write-Output "~-~-~ Game exited, processing PSO Data ~-~-~"

            }

            # -------------  COLLECT  --------------------------   

            # Now copy the recordings to the cache dir
            $recsrc = Join-Path $gamerootdir $projname "Saved" "CollectedPSOs"

            if ($dryrun) {
                Write-Output ""
                Write-Output "Would have copied ${recsrc}/*PCD3D_$($shadermodel)*.rec.upipelinecache to $projPSOcache"
                Write-Output ""
            } else {
                Get-ChildItem -Path $recsrc -Filter "*PCD3D_$($shadermodel)*.rec.upipelinecache" | Copy-Item -Destination $projPSOcache
            }

            # Use the ShaderPipelineCacheTools to generate .spc files

            $uecmd = Join-Path $ueinstall "Engine/Binaries/Win64/UnrealEditor-Cmd$exeSuffix"
            $argList = [System.Collections.ArrayList]@()
            $argList.Add("-run=ShaderPipelineCacheTools") > $null
            $argList.Add("expand") > $null
            # Input Recorded upipelinecache
            $argList.Add("$projPSOcache/*PCD3D_$($shadermodel)*.rec.upipelinecache") > $null
            # Input Shader keys for
            $argList.Add("$projPSOcache/*PCD3D_$($shadermodel).shk") > $null
            # Output .spc file - must be tagged with version ID as prefix, and ProjectName_PCD3D_SM6 pattern is v important
            $argList.Add("$projdir/Build/Windows/PipelineCaches/$($buildID)_$($projname)_PCD3D_$($shadermodel).spc") > $null

            if ($dryrun) {
                Write-Output ""
                Write-Output "Would have run:"
                Write-Output "> $uecmd $($argList -join " ")"
                Write-Output ""

            } else {
                Write-Output "~-~-~ Expanding PSO Data, creating SPC file (bundled PSOs) ~-~-~"

                $proc = Start-Process $uecmd $argList -Wait -PassThru -NoNewWindow
                if ($proc.ExitCode -ne 0) {
                    throw "Creating .spc file failed!"
                }

            }

        }
        
    }



}
catch {
    Write-Output $_.Exception.Message
    Write-Output "~-~-~ Unreal PSO Cache Helper FAILED ~-~-~"
    Exit 9
}


if (-not $dryrun) {
    Write-Output ""
    Write-Output "Your next package build will include the newly created bundled PSOs!"
    Write-Output ""
}
Write-Output "~-~-~ Unreal PSO Cache Helper Completed OK ~-~-~"
