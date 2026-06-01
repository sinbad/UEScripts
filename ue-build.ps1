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
    Write-Output "Usage:"
    Write-Output "  ue-build.ps1 [[-mode:]<dev|test|prod>] [[-src:]sourcefolder] [Options]"
    Write-Output " "
    Write-Output "  -mode        : Build mode"
    Write-Output "               : dev = build Development Editor, dlls only (default)"
    Write-Output "               : cleandev = build Development Editor CLEANLY"
    Write-Output "               : test = build Development and pacakge for test"
    Write-Output "               : prod = build Shipping and package for production"
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

if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}

if (-not ($mode -in @('dev', 'cleandev', 'test', 'prod'))) {
    Print-Usage
    Write-Output "ERROR: Invalid mode argument: $mode"
    Exit 3

}

. $PSScriptRoot\inc\buildcmd.ps1

$result = Build-Project -mode $mode -src $src -nocloseeditor $nocloseeditor -dryrun $dryrun


Exit $result
