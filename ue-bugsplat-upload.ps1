# Helper for uploading symbols to Bugsplat
# Put packageconfig.json in your project folder to configure
# See packageconfig_template.json
[CmdletBinding()] # Fail on unknown args
param (
    # Explicit version to release
    [string]$version,
    # Latest version option instead of explicit version
    [switch]$latest,
    [string]$src,
    # Name of variant to upload (optional, uses DefaultVariants from packageconfig.json if unspecified)
    [array]$variants,
    # Dry-run; does nothing but report what *would* have happened
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\packageconfig.ps1
. $PSScriptRoot\inc\projectversion.ps1
. $PSScriptRoot\inc\uproject.ps1
. $PSScriptRoot\inc\ueeditor.ps1
. $PSScriptRoot\inc\filetools.ps1
. $PSScriptRoot\inc\buildcmd.ps1

function Write-Usage {
    Write-Output "Steve's Unreal Bugsplat Symbol Upload tool"
    Write-Output "Usage:"
    Write-Output "  ue-bugsplat-upload.ps1 [-src:sourcefolder] [-variants=VariantName] [-test] [-dryrun]"
    Write-Output " "
    Write-Output "  -version:ver  : Version to upload; must have been packaged already (or use -latest)"
    Write-Output "  -latest       : Instead of an explicit version, upload one identified in project settings"
    Write-Output "  -src          : Source folder (current folder if omitted), must contain packageconfig.json"
    Write-Output "  -variants Name1,Name2,Name3"
    Write-Output "                : Upload only named variants instead of DefaultVariants from packageconfig.json"
    Write-Output "  -dryrun       : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help         : Print this help"
    Write-Output " "
    Write-Output "Environment Variables:"
    Write-Output "  UEINSTALL   : Use a specific Unreal install."
    Write-Output "              : Default is to find one based on project version, under UEROOT"
    Write-Output "  UEROOT      : Parent folder of all binary Unreal installs (detects version). "
    Write-Output "              : Default C:\Program Files\Epic Games"
    Write-Output " "
    Write-Output "  SYMBOL_UPLOAD_CLIENT_ID     : OAuth client ID defined in Bugsplat"
    Write-Output "  SYMBOL_UPLOAD_CLIENT_SECRET : OAuth secret for Bugsplat"
    Write-Output " "

}


$ErrorActionPreference = "Stop"

if ($help) {
    Write-Usage
    Exit 0
}

if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}

if (-not $version -and -not $latest) {
    Write-Usage
    Write-Output ""
    Write-Output "ERROR: You must specify a version or -latest"
    Exit 1
}

if ($version -and $latest) {
    Write-Usage
    Write-Output ""
    Write-Output "ERROR: You cannot specify a -version and -latest at the same time"
    Exit 1
}

Write-Output "~-~-~ Unreal Bugsplat Helper Start ~-~-~"

try {

    # Import config
    $config = Read-Package-Config -srcfolder:$src
    $projfile = Get-Uproject-Filename -srcfolder:$src -config:$config
    $proj = Read-Uproject $projfile
    $ueVersion = Get-UE-Version $proj

    if ($config.BugsplatDatabase.Length -eq 0) {
         Write-Output "BugsplatDatabase is not set in packageconfig.json"
         Exit 1
    }
    if ($config.BugsplatApp.Length -eq 0) {
         Write-Output "BugsplatApp is not set in packageconfig.json"
         Exit 1
    }

    if ($latest) {
        $version = Get-Project-Version $src
    }

    if ($variants) {
        $variantConfigs = $config.Variants | Where-Object { $_.Name -in $variants }
        if ($variantConfigs.Count -ne $variants.Count) {
            $unmatchedVariants = $variants | Where-Object { $_ -notin $variantConfigs.Name } 
            Write-Warning "Variant(s) not found, ignoring: $($unmatchedVariants -join ", ")"
        }
    } else {
        # Use default variants
        $variantConfigs = $config.Variants | Where-Object { $_.Name -in $config.DefaultVariants }
    }

    $hasErrors = $false
    foreach ($variantConfig in $variantConfigs) {

        # Get source dir
        $sourcedir = Get-Debug-Symbols-Dir -config:$config -versionNumber:$version -variantName:$variantConfig.Name -ueVersion:$ueVersion

        if (-not (Test-Path $sourcedir -PathType Container)) {
            Write-Error "PDB source folder $sourcedir does not exist, skipping"
            $hasErrors = $true
            continue
        }

        Write-Output ""
        Write-Output "Variant         : $($variantConfig.Name)"
        Write-Output "Version         : $version"
        Write-Output "Source Folder   : $sourcedir"
        Write-Output "Bugsplat DB     : $config.BugsplatDatabase"
        Write-Output "Bugsplat App    : $config.BugsplatApp"
        Write-Output ""

        $symbolupload = "symbol-upload-windows.exe"
        $uploadargs = "-f `"**/*.{pdb,exe,dll}`" -b $($config.BugsplatDatabase) -a $($config.BugsplatApp) -v $version"

        if ($dryrun) {
            Write-Host "Would run: $symbolupload $uploadargs"
            Write-Host "In directory $sourcedir"
        } else {
            Write-Verbose "Running $symbolupload $uploadargs"

            # symbol-upload uploads from the *current dir*
            Push-Location $sourcedir
            $proc = Start-Process $symbolupload $uploadargs -PassThru -NoNewWindow | Wait-Process -PassThru
            if ($proc.ExitCode -ne 0) {
                Pop-Location
                $code = $proc.ExitCode
                throw "*** Upload exited with code $code, see above"
            }
            Pop-Location
        }

    }

    if ($hasErrors) {
        throw "Errors occurred, see above"
    }

} catch {
    Write-Output $_.Exception.Message
    Write-Output "~-~-~ Unreal Bugsplat Helper FAILED ~-~-~"
    Exit 9
}


Write-Output "~-~-~ Unreal Bugsplat Helper Completed OK ~-~-~"
