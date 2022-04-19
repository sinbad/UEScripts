[CmdletBinding()] # Fail on unknown args
param (
    [string]$mode,
    [string]$src,
    [switch]$nocloseeditor = $false,
    [switch]$dryrun = $false,
    [switch]$help = $false
)

function Print-Usage {
    Write-Output "Steve's Unreal Build Tool"
    Write-Output "   This is a WIP, only builds for dev right now"
    Write-Output "Usage:"
    Write-Output "  ue4-build.ps1 [[-mode:]<dev|test|prod>] [[-src:]sourcefolder] [Options]"
    Write-Output " "
    Write-Output "  -mode        : Build mode"
    Write-Output "               : dev = build Development Editor, dlls only (default)"
    Write-Output "               : cleandev = build Development Editor CLEANLY"
    Write-Output "               : test = build Development and pacakge for test (TODO)"
    Write-Output "               : prod = build Shipping and package for production (TODO)"
    Write-Output "  -src         : Source folder (current folder if omitted)"
    Write-Output "               : (should be root of project)"
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

$ErrorActionPreference = "Stop"


if ($help) {
    Print-Usage
    Exit 0
}

if (-not $mode) {
    $mode = "dev"
}

if (-not ($mode -in @('dev', 'cleandev', 'test', 'prod'))) {
    Print-Usage
    Write-Output "ERROR: Invalid mode argument: $mode"
    Exit 3

}


$result = 0

try {
    if ($src -ne ".") { Push-Location $src }

    Write-Output "-- Build process starting --"

    # Locate Unreal project file
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
        Write-Output "Would build $uprojname for $mode"
    } else {
        Write-Output "Building $uprojname for $mode"
    }

    # Check version number of Unreal project so we know which version to run
    # We can read this from .uproject which is JSON
    $uproject = Get-Content $uprojfile | ConvertFrom-Json
    $uversion = $uproject.EngineAssociation

    Write-Output "Engine version is $uversion"

    # UEINSTALL env var should point at the root of the *specific version* of 
    # Unreal you want to use. This is mainly for use in source builds, default is
    # to build it from version number and root of all UE binary installs
    $uinstall = $Env:UEINSTALL

    # Backwards compat with old env var
    if (-not $uinstall) {
        $uinstall = $Env:UE4INSTALL
    }

    if (-not $uinstall) {
        # UEROOT should be the parent folder of all UE versions
        $uroot = $Env:UEROOT
        # Backwards compat with old env var
        if (-not $uroot) {
            $uroot = $Env:UE4ROOT
        }
        if (-not $uroot) {
            $uroot = "C:\Program Files\Epic Games"
        } 

        $uinstall = Join-Path $uroot "UE_$uversion"
    }

    # Test we can find Build.bat
    $batchfolder = Join-Path "$uinstall" "Engine\Build\BatchFiles"
    $buildbat = Join-Path "$batchfolder" "Build.bat"
    if (-not (Test-Path $buildbat -PathType Leaf)) {
        throw "Build.bat missing at $buildbat : Aborting"
    }

    $buildargs = ""

    switch ($mode) {
        'dev' {
            # Stolen from the VS project settings because boy is this badly documented
            # Target needs "Editor" on the end to make this "Development Editor"
            # The -Project seems to be needed, as is the -FromMsBuild
            # -Project has to point at the ABSOLUTE PATH of the uproject
            $uprojfileabs = Join-Path "$(Get-Location)" $uprojfile
            $buildargs = "${uprojname}Editor Win64 Development -Project=`"${uprojfileabs}`" -WaitMutex -FromMsBuild"
        }
        'cleandev' {
            $uprojfileabs = Join-Path "$(Get-Location)" $uprojfile
            $buildargs = "${uprojname}Editor Win64 Development -Project=`"${uprojfileabs}`" -WaitMutex -FromMsBuild -clean"
        }
        default {
            # TODO
            # We probably want to use custom launch profiles for this
            Write-Output "Mode '$mode' is not supported yet"
        }
    }

    if ($dryrun) {
        Write-Output "Would run: build.bat $buildargs"
    } else {
        Write-Verbose "Running $buildbat $buildargs"

        $proc = Start-Process $buildbat $buildargs -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            $code = $proc.ExitCode
            throw "*** Build exited with code $code, see above"
        }
    }

    Write-Output "-- Build process finished OK --"

} catch {
        Write-Output "ERROR: $($_.Exception.Message)"
        $result = 9
} finally {
    if ($src -ne ".") { Pop-Location }
}


Exit $result
