[CmdletBinding()] # Fail on unknown args
param (
    [string]$mode,
    [string]$src,
    [switch]$nocloseeditor = $false,
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\pluginconfig.ps1
. $PSScriptRoot\inc\pluginversion.ps1
. $PSScriptRoot\inc\uproject.ps1
. $PSScriptRoot\inc\uplugin.ps1
. $PSScriptRoot\inc\filetools.ps1

function Print-Usage {
    Write-Output "Steve's Unreal Plugin Build Tool"
    Write-Output "Usage:"
    Write-Output "  ue-build-plugin.ps1 [[-src:]sourcefolder] [Options]"
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

if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}

if ($help) {
    Print-Usage
    Exit 0
}


$result = 0

try {
    if ($src -ne ".") { Push-Location $src }

    Write-Output "-- Build plugin process starting --"

    $config = Read-Plugin-Config -srcfolder:$src

    # Locate Unreal project file
    $pluginfile = Get-Uplugin-Filename -srcfolder:$src -config:$config
    if (-not $pluginfile) {
        throw "Not in a uplugin dir!"
    }

    $proj = Read-Uproject $pluginfile
    $ueVersion = Get-UE-Version $proj
    $ueinstall = Get-UE-Install $ueVersion
    
    Write-Output ""
    Write-Output "Project File    : $projfile"
    Write-Output "UE Version      : $ueVersion"
    Write-Output "UE Install      : $ueinstall"
    Write-Output "Output Folder   : $($config.BuildDir)"
    Write-Output ""

    $runUAT = Join-Path $ueinstall "Engine/Build/BatchFiles/RunUAT$batchSuffix"

    $targetPlatform = Get-Platform

    $argList = [System.Collections.ArrayList]@()
    $argList.Add("BuildPlugin") > $null
    $argList.Add("-Plugin=`"$pluginfile`"") > $null
    $argList.Add("-Package=`"$($config.BuildDir)`"") > $null
    $argList.Add("-Rocket") > $null
    $argList.Add("-TargetPlatforms=$targetPlatform") > $null

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


    Write-Output "-- Build plugin process finished OK --"

} catch {
        Write-Output "ERROR: $($_.Exception.Message)"
        $result = 9
} finally {
    if ($src -ne ".") { Pop-Location }
}


Exit $result
