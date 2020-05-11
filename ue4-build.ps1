[CmdletBinding()] # Fail on unknown args
param (
    [string]$mode,
    [string]$src,
    [switch]$nocloseeditor = $false,
    [switch]$dryrun = $false,
    [switch]$help = $false
)

function Print-Usage {
    Write-Output "Steve's UE4 Build Tool"
    Write-Output "   This is a WIP, only builds for dev right now"
    Write-Output "Usage:"
    Write-Output "  ue4-build.ps1 [-mode:]<dev|test|prod> [[-src:]sourcefolder] [Options]"
    Write-Output " "
    Write-Output "  -mode        : Build mode (required)"
    Write-Output "               : dev = build Development Editor, dlls only"
    Write-Output "               : dev = build Development Editor locally for editor"
    Write-Output "               : test = build Development and pacakge for test (TODO)"
    Write-Output "               : prod = build Shipping and package for production (TODO)"
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

if (-not $mode) {
    Print-Usage
    Write-Output "ERROR: Required argument: mode"
    Exit 3
}

if (-not ($mode -in @('dev', 'test', 'prod'))) {
    Print-Usage
    Write-Output "ERROR: Invalid mode argument: $mode"
    Exit 3

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
    Write-Output "Building $uprojname for $mode"

    # Check version number of UE4 project so we know which version to run
    # We can read this from .uproject which is JSON
    $uproject = Get-Content $uprojfile | ConvertFrom-Json
    $uversion = $uproject.EngineAssociation

    # UE4INSTALL env var should point at the root of the *specific version* of 
    # UE4 you want to use. This is mainly for use in source builds, default is
    # to build it from version number and root of all UE4 binary installs
    $uinstall = $Env:UE4INSTALL

    if (-not $uinstall) {
        # UE4ROOT should be the parent folder of all UE versions
        $uroot = $Env:UE4ROOT
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

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $buildbat
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.Arguments = $buildargs
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $pinfo
        $process.Start() | Out-Null

        Write-Host "UE4 Build: " -NoNewline
        do {
            Write-Host "." -NoNewline
            start-sleep -Milliseconds 1000
        } until ($process.HasExited)
        Write-Host "."

        if ($process.ExitCode -ne 0) {
            $code = $process.ExitCode
            Write-Output $process.StandardOutput.ReadToEnd()
            Write-Output $process.StandardError.ReadToEnd()
            throw "*** Build exited with code $code, see above"
        } else {
            Write-Verbose $process.StandardOutput.ReadToEnd()           
            Write-Output "---- UE4 Build OK ----"
        }
    }


    # Try to locate RunUAT.bat so we don't have to add UE4 version to PATH
    # Most likely in
    # C:\Program Files\Epic Games\UE_4.24\Engine\Build\BatchFiles


} catch {
        Write-Output "ERROR: $($_.Exception.Message)"
        $result = 9
} finally {
    if ($src -ne ".") { Pop-Location }
}


Exit $result
