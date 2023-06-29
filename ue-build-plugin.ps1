[CmdletBinding()] # Fail on unknown args
param (
    [string]$mode,
    [string]$src,
    [switch]$allplatforms = $false,
    [switch]$allversions = $false,
    [string]$uever = "",
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
    Write-Output "  -src          : Source folder (current folder if omitted)"
    Write-Output "                : (should be root of project)"
    Write-Output "  -allplatforms : Build for all platforms, not just the current one"
    Write-Output "  -allversions  : Build for all supported UE versions, not just the current one"
    Write-Output "                : (specified in pluginconfig.json, only works with lancher-installed UE)"
    Write-Output "  -uever:5.x.x  : Build for a specific UE version, not the current one (launcher only)"
    Write-Output "  -dryrun       : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help         : Print this help"
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
    $origUeVersion = Get-UE-Version $proj
    if ($allversions) {
        $ueVersions = $config.EngineVersions
    } elseif ($uever.Length -gt 0) {
        $ueVersions = @($uever)
    } else {
        $ueVersions = @($origUeVersion)
    }

    
    Write-Output ""
    Write-Output "Project File    : $pluginfile"
    Write-Output "UE Version(s)   : $($ueVersions -join `", `")"
    Write-Output "Output Folder   : $($config.BuildDir)"
    Write-Output ""

    foreach ($ver in $ueVersions) {

        Write-Output "Building for UE Version $ver"
        $ueinstall = Get-UE-Install $ver
        $outputDir = Join-Path $config.BuildDir $ver

        # Need to change the version in the plugin while we build
        if (-not $dryrun -and ($allversions -or $ueVer.Length -gt 0)) {
            Update-UpluginUeVersion $src $config $ver
        }

        $runUAT = Join-Path $ueinstall "Engine/Build/BatchFiles/RunUAT$batchSuffix"    

        $argList = [System.Collections.ArrayList]@()
        $argList.Add("BuildPlugin") > $null
        $argList.Add("-Plugin=`"$pluginfile`"") > $null
        $argList.Add("-Package=`"$outputDir`"") > $null
        $argList.Add("-Rocket") > $null

        if (-not $allplatforms) {
            $targetPlatform = Get-Platform
            $argList.Add("-TargetPlatforms=$targetPlatform") > $null    
        }

        if ($dryrun) {
            Write-Output ""
            Write-Output "Would have run:"
            Write-Output "> $runUAT $($argList -join " ")"
            Write-Output ""

        } else {            
            $proc = Start-Process $runUAT $argList -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -ne 0) {
                # Reset the plugin back to the original UE version
                if ($allversions -and -not $dryrun) {
                    Update-UpluginUeVersion $src $config $origUeVersion
                }

                throw "RunUAT failed!"
            }
        }
    }

    # Reset the plugin back to the original UE version
    if ($allversions -and -not $dryrun) {
        Update-UpluginUeVersion $src $config $origUeVersion
    }

    Write-Output "-- Build plugin process finished OK --"

} catch {
        Write-Output "ERROR: $($_.Exception.Message)"
        $result = 9
} finally {
    if ($src -ne ".") { Pop-Location }
}


Exit $result
