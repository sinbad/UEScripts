[CmdletBinding()] # Fail on unknown args
param (
    [string]$src,
    [switch]$nocloseeditor = $false,
    [switch]$dryrun = $false,
    [switch]$help = $false
)

function Print-Usage {
    Write-Output "Steve's UE4 Get Latest Tool"
    Write-Output "   Get latest from repo and build for dev. Will close UE4 editor!"
    Write-Output "Usage:"
    Write-Output "  ue4-get-latest.ps1 [[-src:]sourcefolder] [Options]"
    Write-Output " "
    Write-Output "  -src         : Source folder (current folder if omitted)"
    Write-Output "               : (should be root of project)"
    Write-Output "  -nocloseeditor : Don't close UE4 editor (this will prevent DLL cleanup)"
    Write-Output "  -dryrun      : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help        : Print this help"
    Write-Output " "
    Write-Output "Environment Variables:"
    Write-Output "  UE4INSTALL   : Use a specific UE4 install."
    Write-Output "               : Default is to find one based on project version, under UE4ROOT"
    Write-Output "  UE4ROOT      : Parent folder of all binary UE4 installs (detects version). "
    Write-Output "               : Default C:\Program Files\Epic Games"
    Write-Output " "

}

$ErrorActionPreference = "Stop"

if ($help) {
    Print-Usage
    Exit 0
}

$result = 0

try {
    if ($src -ne ".") { Push-Location $src }

    # Make sure we're running in the root of the project
    $uprojfile = Get-ChildItem *.uproject | Select-Object -expand Name
    if (-not $uprojfile) {
        throw "No Unreal project file found in $(Get-Location)! Aborting."
    }
    if ($uprojfile -is [array]) {
        throw "Multiple Unreal project files found in $(Get-Location)! Aborting."
    }

    $isGit = Test-Path .git

    if ($isGit) {
        git diff --ignore-submodules --no-patch --exit-code > $null
        $unstagedChanges = ($LASTEXITCODE -ne 0)
        git diff --ignore-submodules --no-patch --cached --exit-code > $null
        $stagedChanges = ($LASTEXITCODE -ne 0)

        if ($unstagedChanges -or $stagedChanges) {
            if ($dryrun) {
                Write-Output "Changes present, would have run 'git stash push'"
            } else {
                Write-Output "Working copy has changes, saving them in stash"
                git stash push -q -m "Saved changes during Get Latest"
                if ($LASTEXITCODE -ne 0) {
                    Write-Output "ERROR: git stash push failed, aborting"
                    exit 5
                }
            }
        }

        # Use rebase pull to keep simpler
        Write-Output "Pulling latest from Git..."
        git pull --rebase
        if ($LASTEXITCODE -ne 0) {
            Write-Output "ERROR: git pull failed!"
            exit 5
        }

        if ($unstagedChanges -or $stagedChanges) {
            Write-Output "Re-applying your saved changes..."
            git stash pop > $null
            if ($LASTEXITCODE -ne 0) {
                Write-Output "ERROR: Failed to re-apply your changes, resolve manually from stash!"
                exit 5
            }
        }
    } else {
        # Assume svn

        # Hard coded for Subversion right now
        if ($dryrun) {
            Write-Output "Checking for updates we WOULD do:"
            svn status --show-updates
        } else {
            Write-Output "Updating to latest..."
            svn up
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Subversion update failed, see above"
        }
    }

    # Now build
    $args = @()
    if ($nocloseeditor) {
        $args += "-nocloseeditor"
    }
    if ($dryrun) {
        $args += "-dryrun"
    }
    # Use Invoke-Expression so we can use a string as options
    Invoke-Expression "&'$PSScriptRoot/ue4-build.ps1' dev $args"

    if ($LASTEXITCODE -ne 0) {
        throw "Build process failed, see above"
    }

    Write-Output "-- Get Latest finished OK --"


} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    $result = 9
} finally {
    if ($src -ne ".") { Pop-Location }
}

Exit $result

