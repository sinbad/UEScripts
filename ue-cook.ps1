[CmdletBinding()] # Fail on unknown args
param (
    [string]$src,
    [switch]$nocloseeditor = $false,
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\packageconfig.ps1
. $PSScriptRoot\inc\projectversion.ps1
. $PSScriptRoot\inc\uproject.ps1
. $PSScriptRoot\inc\filetools.ps1

function Print-Usage {
    Write-Output "Steve's Unreal Build Tool"
    Write-Output "Usage:"
    Write-Output "  ue-build.ps1 [[-mode:]<dev|test|prod>] [[-src:]sourcefolder] [Options]"
    Write-Output " "
    Write-Output "  -src         : Source folder (current folder if omitted)"
    Write-Output "               : (should be root of project)"
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

if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}


$result = 0

try {
    if ($src -ne ".") { Push-Location $src }

    Write-Output "-- Cook process starting --"

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
        Write-Output "Would cook $uprojname"
    } else {
        Write-Output "Cooking $uprojname"
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
    $ueEditorCmd = Get-UEEditorCmd $uversion $uinstall
    $runUAT = Join-Path $uinstall "Engine/Build/BatchFiles/RunUAT$batchSuffix"

    $absuprojectfile = Resolve-Path $uprojfile
    $platform = Get-Platform

    $argList = [System.Collections.ArrayList]@()
    $argList.Add("-ScriptsForProject=`"$absuprojectfile`"") > $null
    $argList.Add("BuildCookRun") > $null
    $argList.Add("-skipbuildeditor") > $null
    $argList.Add("-nocompileeditor") > $null
    #$argList.Add("-installed")  > $null # don't think we need this, seems to be detected
    $argList.Add("-nop4") > $null
    $argList.Add("-project=`"$absuprojectfile`"") > $null
    $argList.Add("-cook") > $null
    $argList.Add("-skipstage") > $null
    $argList.Add("-nocompile") > $null
    $argList.Add("-nocompileuat") > $null
    if ((Get-Is-UE5 $uversion)) {
        $argList.Add("-unrealexe=`"$ueEditorCmd`"") > $null
    } else {
        $argList.Add("-ue4exe=`"$ueEditorCmd`"") > $null
    }
    $argList.Add("-platform=$($platform)") > $null
    $argList.Add("-target=$($uprojname)") > $null
    $argList.Add("-utf8output") > $null
    if ($maps.Count) {
        $argList.Add("-Map=$($maps -join "+")") > $null
    }

    if ($dryrun) {
        Write-Output ""
        Write-Output "Would have run:"
        Write-Output "> $runUAT $($argList -join " ")"
        Write-Output ""

    } else {            
        $proc = Start-Process $runUAT $argList -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            throw "RunUAT failed!"
        }

    }

    Write-Output "-- Cook process finished OK --"

} catch {
        Write-Output "ERROR: $($_.Exception.Message)"
        $result = 9
} finally {
    if ($src -ne ".") { Pop-Location }
}


Exit $result
