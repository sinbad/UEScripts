# Blueprint bulk recompile helper
[CmdletBinding()] # Fail on unknown args
param (
    # Optional source folder, assumed current folder
    [string]$src,
    # Optional subfolder of Content to parse, default "Blueprints"
    [string]$bpdir = "Blueprints",
    # Dry-run; does nothing but report what *would* have happened
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\packageconfig.ps1
. $PSScriptRoot\inc\projectversion.ps1
. $PSScriptRoot\inc\uproject.ps1
. $PSScriptRoot\inc\filetools.ps1

# Include Git tools locking
. $PSScriptRoot\GitScripts\inc\locking.ps1

function Write-Usage {
    Write-Output "Steve's Unreal Blueprint recompile tool"
    Write-Output "Usage:"
    Write-Output "  ue-blueprint-recompile.ps1 [-src:sourcefolder] [-bpdir:blueprintdir] [-dryrun]"
    Write-Output " "
    Write-Output "  -src          : Source folder (current folder if omitted)"
    Write-Output "  -bpdir        : Path to Blueprints relative to your Content dir, defaults to 'Blueprints'"
    Write-Output "  -dryrun       : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help         : Print this help"
    Write-Output " "
    Write-Output "Environment Variables:"
    Write-Output "  UEINSTALL   : Use a specific UE install."
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

if ($help) {
    Write-Usage
    Exit 0
}

Write-Output "~-~-~ Unreal Blueprint Recompile Start ~-~-~"

try {
    
    $config = Read-Package-Config -srcfolder:$src
    $projfile = Get-Uproject-Filename -srcfolder:$src -config:$config
    $proj = Read-Uproject $projfile
    $ueVersion = Get-UE-Version $proj
    $ueinstall = Get-UE-Install $ueVersion

    Write-Output ""
    Write-Output "Project File  : $projfile"
    Write-Output "UE Version    : $ueVersion"
    Write-Output "UE Install    : $ueinstall"
    Write-Output "Blueprint Dir : Content/$bpdir"
    Write-Output ""

    $bpfullpath = Join-Path $src "Content/$bpdir" -Resolve

    $argList = [System.Collections.ArrayList]@()
    $argList.Add("`"$projfile`"") > $null
    $argList.Add("-run=ResavePackages") > $null
    $argList.Add("-packagefolder=`"$bpfullpath`"") > $null
    $argList.Add("-autocheckout") > $null

    $ueEditorCmd = Get-UEEditorCmd $ueVersion $ueinstall

    if ($dryrun) {
        Write-Output "Would have run:"
        Write-Output "> $ueEditorCmd $($argList -join " ")"

    } else {
        $proc = Start-Process $ueEditorCmd $argList -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            throw "Blueprint recompile build failed!"
        }

    }

} catch {
    Write-Output $_.Exception.Message
    Write-Output "~-~-~ Unreal Blueprint Recompile FAILED ~-~-~"
    Exit 9

}


Write-Output "~-~-~ Unreal Blueprint Recompile OK ~-~-~"
if (!$dryrun) {
    Write-Output "Reminder: You may need to commit and unlock Blueprint files"
}
