[CmdletBinding()] # Fail on unknown args
param (
    [string]$src,
    [switch]$nocloseeditor = $false,
    [switch]$dryrun = $false,
    [switch]$help = $false
)

function Print-Usage {
    Write-Output "Steve's UE4 Project Cleanup Tool"
    Write-Output "   Get latest from repo and build for dev. Will close UE4 editor!"
    Write-Output "Usage:"
    Write-Output "  ue4-cleanup.ps1 [[-src:]sourcefolder] [Options]"
    Write-Output " "
    Write-Output "  -src         : Source folder (current folder if omitted)"
    Write-Output "               : (should be root of project)"
    Write-Output "  -nocloseeditor : Don't close UE4 editor (this will prevent DLL cleanup)"
    Write-Output "  -nolfsprune  : Don't call 'git lfs prune' to delete old LFS files"
    Write-Output "  -dryrun      : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help        : Print this help"
    Write-Output " "
}

function Cleanup-DLLs($cleanupdir, $projname, $dryrun) {
    if ($dryrun) {
        Write-Output "Would clean up old Hot Reload DLLs/PDBs in $cleanupdir for $projname"
    } else {
        Write-Output "Cleaning up old Hot Reload DLLs/PDBs in $cleanupdir for $projname"
    }
    $cleanupfiles = @(Get-ChildItem "$cleanupdir\UE4Editor-$projname-????.dll" | Select-Object -Expand Name)
    $cleanupfiles += @(Get-ChildItem "$cleanupdir\UE4Editor-$projname-????.pdb" | Select-Object -Expand Name)
    foreach ($cf in $cleanupfiles) {
        if ($dryrun) {
            Write-Output "Would have deleted $cleanupdir\$cf"
        } else {
            Write-Verbose "Deleting $cleanupdir\$cf"
            Remove-Item "$cleanupdir\$cf" -Force
        }
    }


}

$ErrorActionPreference = "Stop"

if ($help) {
    Print-Usage
    Exit 0
}

$result = 0

try {
    if ($src -ne ".") { Push-Location $src }

    # Locate UE4 project file
    $uprojfile = Get-ChildItem *.uproject | Select-Object -expand Name
    if (-not $uprojfile) {
        throw "No Unreal project file found in $(Get-Location)! Aborting."
    }
    if ($uprojfile -is [array]) {
        throw "Multiple Unreal project files found in $(Get-Location)! Aborting."
    }

    # In PS 6.0+ we could use Split-Path -LeafBase but let's stick with built-in PS 5.1
    $uprojname = [System.IO.Path]::GetFileNameWithoutExtension($uprojfile)
    if ($dryrun) {
        Write-Output "Would clean up $uprojname"
    } else {
        Write-Output "Cleaning up $uprojname"
    }

    # Close UE4 as early as possible
    if (-not $nocloseeditor) {
        # Check if UE4 is running, if so try to shut it gracefully
        # Filter by project name in main window title, it's always called "Project - Unreal Editor"
        $ue4proc = Get-Process UE4Editor -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowTitle -like "$uprojname*" }
        if ($ue4proc) {
            if ($dryrun) {
                Write-Output "UE4 project is currently open in editor, would have closed"
            } else {
                Write-Output "UE4 project is currently open in editor, closing..."
                $ue4proc.CloseMainWindow() > $null 
                Start-Sleep 5
                if (!$ue4proc.HasExited) {
                    throw "Couldn't close UE4 gracefully, aborting!"
                }
            }
        } else {
            Write-Verbose "UE4 project is not open in editor"
        }
        Remove-Variable ue4proc

        # Because we know editor is closed, Hot Reload DLLs are OK to clean up
        Cleanup-DLLs ".\Binaries\Win64" $uprojname $dryrun

        # Also clean up plugins, since they will be rebuilt
        $plugins = Get-ChildItem -Path .\Plugins -Filter *.uplugin -Recurse -ErrorAction SilentlyContinue -Force
        foreach ($pluginfile in $plugins) {
            $pluginname = [System.IO.Path]::GetFileNameWithoutExtension($pluginfile.FullName)
            if ($dryrun) {
                Write-Output "Would clean up plugin $pluginname"
            } else {
                Write-Output "Cleaning up plugin $pluginname"
            }
            $pluginroot = Resolve-Path $pluginfile.DirectoryName -Relative
            $pluginbinaries = Join-Path $pluginroot "Binaries\Win64"
            Cleanup-DLLs $pluginbinaries $pluginname $dryrun
        }

    }

    
    $isGit = Test-Path .git
    if ($isGit) {
        if (-not $nolfsprune) {
            if ($dryrun) {
                Write-Output "Would have pruned LFS files"
                git lfs prune --dry-run
            } else {
                Write-Output "Pruning Git LFS files"
                git lfs prune
            }
        }
    }
    Write-Output "-- Cleanup finished OK --"


} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    $result = 9
} finally {
    if ($src -ne ".") { Pop-Location }
}

Exit $result

