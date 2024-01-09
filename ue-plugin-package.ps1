# Plugin packaging helper
# Bumps versions, zips for marketplace
# Put pluginconfig.json in your project folder to configure
# See pluginconfig_template.json
[CmdletBinding()] # Fail on unknown args
param (
    [string]$src,
    [switch]$major = $false,
    [switch]$minor = $false,
    [switch]$patch = $false,
    [switch]$hotfix = $false,
    # Don't incrememnt version
    [switch]$keepversion = $false,
    # Never tag
    [switch]$notag = $false,
    # Testing mode; skips clean checks, tags
    [switch]$test = $false,
    # Browse the output directory in file explorer after packaging
    [switch]$browse = $false,
    # Dry-run; does nothing but report what *would* have happened
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\pluginconfig.ps1
. $PSScriptRoot\inc\pluginversion.ps1
. $PSScriptRoot\inc\uproject.ps1
. $PSScriptRoot\inc\uplugin.ps1
. $PSScriptRoot\inc\filetools.ps1


function Write-Usage {
    Write-Output "Steve's Unreal Plugin packaging tool"
    Write-Output "Usage:"
    Write-Output "  ue-plugin-package.ps1 [-src:sourcefolder] [-major|-minor|-patch|-hotfix] [-keepversion] [-force] [-test] [-dryrun]"
    Write-Output " "
    Write-Output "  -src          : Source folder (current folder if omitted), must contain pluginconfig.json"
    Write-Output "  -major        : Increment major version i.e. [x++].0.0.0"
    Write-Output "  -minor        : Increment minor version i.e. x.[x++].0.0"
    Write-Output "  -patch        : Increment patch version i.e. x.x.[x++].0 (default)"
    Write-Output "  -hotfix       : Increment hotfix version i.e. x.x.x.[x++]"
    Write-Output "  -keepversion  : Keep current version number, doesn't tag unless -forcetag"
    Write-Output "  -notag        : Don't tag even if updating version"
    Write-Output "  -test         : Testing mode, separate builds, allow dirty working copy"
    Write-Output "  -browse       : After packaging, browse the output folder"
    Write-Output "  -dryrun       : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help         : Print this help"
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

Write-Output "~-~-~ Unreal Plugin Package Start ~-~-~"

if ($test) {
    Write-Output "TEST MODE: No tagging, version bumping"
}

if (([bool]$major + [bool]$minor + [bool]$patch + [bool]$hotfix) -gt 1) {
    Write-Output "ERROR: Can't set more than one of major/minor/patch/hotfix at the same time!"
    Print-Usage
    Exit 5
}
if (($major -or $minor -or $patch -or $hotfix) -and $keepversion) {
    Write-Output  "ERROR: Can't set keepversion at the same time as major/minor/patch/hotfix!"
    Print-Usage
    Exit 5
}

# Detect Git
if ($src -ne ".") { Push-Location $src }
$isGit = Test-Path ".git"
if ($src -ne ".") { Pop-Location }

# Check working copy is clean (Git only)
if (-not $test -and $isGit) {
    if ($src -ne ".") { Push-Location $src }

    if (Test-Path ".git") {
        git diff --no-patch --exit-code
        if ($LASTEXITCODE -ne 0) {
            Write-Output "Working copy is not clean (unstaged changes)"
            if ($dryrun) {
                Write-Output "dryrun: Continuing but this will fail without -dryrun"
            } else {
                Exit $LASTEXITCODE
            }
        }
        git diff --no-patch --cached --exit-code
        if ($LASTEXITCODE -ne 0) {
            Write-Output "Working copy is not clean (staged changes)"
            if ($dryrun) {
                Write-Output "dryrun: Continuing but this will fail without -dryrun"
            } else {
                Exit $LASTEXITCODE
            }
        }
    }
    if ($src -ne ".") { Pop-Location }
}


try {
    # Import config & project settings
    $config = Read-Plugin-Config -srcfolder:$src
    # Need to explicitly set to UTF8, Out-File now converts to UTF16-LE??
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

    $pluginfile = Get-Uplugin-Filename -srcfolder:$src -config:$config
    if (-not $pluginfile) {
        throw "Not in a uplugin dir!"
    }
    $proj = Read-Uproject $pluginfile
    $pluginName = (Get-Item $pluginfile).Basename

    # Default to latest engine if not specified
    if (-not $config.EngineVersions -or $config.EngineVersions.Length -eq 0) {
        Write-Output "Warning: EngineVersions missing from pluginconfig.json, assuming latest only"
        $config.EngineVersions = [System.Collections.ArrayList]@()
        $config.EngineVersions.add($proj.EngineVersion) > $null
    }

    Write-Output ""
    Write-Output "Plugin File     : $pluginfile"
    Write-Output "Output Folder   : $($config.PackageDir)"
    Write-Output "Engine Versions : $($config.EngineVersions -join ", ")"
    Write-Output ""

    if (([bool]$major + [bool]$minor + [bool]$patch + [bool]$hotfix) -eq 0) {
        $patch = $true
    }
    $versionNumber = $proj.VersionName
    if (-not $keepversion) {
        # Bump up version, passthrough options
        try {
            $versionNumber = Get-NextPluginVersion -current:$versionNumber -major:$major -minor:$minor -patch:$patch -hotfix:$hotfix
            # Save incremented version back to uplugin object
            $proj.VersionName = $versionNumber
            if (-not $dryrun -and $isGit -and -not $notag) {
                # Save this now, we need to commit before tagging
                Write-Output "Incrementing version in .uproject"
                $newjson = ($proj | ConvertTo-Json -depth 100)
                [System.IO.File]::WriteAllLines($pluginfile, $newjson, $Utf8NoBomEncoding)

                git add .
                git commit -m "Version bump" 
            }
        }
        catch {
            Write-Output $_.Exception.Message
            Exit 6
        }
    }
    Write-Output "Next version will be: $versionNumber"

    # For tagging release
    # We only need to grab the main version once
    if (-not ($keepversion -or $notag)) {
        
        if (-not $test -and -not $dryrun -and $isGit) {
            if ($src -ne ".") { Push-Location $src }
            git tag -a $versionNumber -m "Automated release tag"
            if ($LASTEXITCODE -ne 0) { Exit $LASTEXITCODE }
            if ($src -ne ".") { Pop-Location }
        }
    }

    $resetinstalled = $false
    if (-not $proj.Installed) {
        # Need to set the installed=true for marketplace
        $proj.Installed = $true
        $resetinstalled = $true
    }

    # Marketplace requires you to submit one package per EngineVersion for code plugins
    # Pretty dumb since the only diff is the EngineVersion in .uplugin but sure
    $oldEngineVer = $proj.EngineVersion
    foreach ($EngineVer in $config.EngineVersions) {
        Write-Output "Packaging for Engine Version $EngineVer"
        $proj.EngineVersion = $EngineVer

        $newjson = ($proj | ConvertTo-Json -depth 100)
        if (-not $dryrun) {
            Write-Output "Writing updates to .uproject"
            [System.IO.File]::WriteAllLines($pluginfile, $newjson, $Utf8NoBomEncoding)

        }

        # Zip parent of the uplugin folder
        $zipsrc = (Get-Item $pluginfile).Directory.FullName
        $zipdst = Join-Path $config.PackageDir "$($pluginName)_v$($versionNumber)_UE$($EngineVer).zip"
        $excludefilename = "packageexclusions.txt"
        $excludefile = Join-Path $zipsrc $excludefilename

        New-Item -ItemType Directory -Path $config.PackageDir -Force > $null
        Write-Output "Compressing to $zipdst"

        $argList = [System.Collections.ArrayList]@()
        $argList.Add("a") > $null
        $argList.Add($zipdst) > $null
        # Standard exclusions
        $argList.Add("-x!$pluginName\.git\") > $null
        $argList.Add("-x!$pluginName\.git*") > $null
        $argList.Add("-x!$pluginName\Binaries\") > $null
        $argList.Add("-x!$pluginName\Intermediate\") > $null
        $argList.Add("-x!$pluginName\Saved\") > $null
        $argList.Add("-x!$pluginName\pluginconfig.json") > $null

        if (Test-Path $excludefile) {
            $argList.Add("-x@`"$excludefile`"") > $null
        $argList.Add("-x!$pluginName\$excludefilename") > $null
        }

        $argList.Add($zipsrc) > $null

        if ($dryrun) {
            Write-Output ""
            Write-Output "Would have run:"
            Write-Output "> 7z.exe $($argList -join " ")"
            Write-Output ""

        } else {      
            Remove-Item -Path $zipdst -Force -ErrorAction SilentlyContinue
            $proc = Start-Process "7z.exe" $argList -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -ne 0) {
                throw "7-Zip failed!"
            }

        }

    }


    # Reset the uplugin
    # Otherwise UE keeps prompting to update project files when using it as source
    if ($resetinstalled) {
        $proj.Installed = $false
    }
    $proj.EngineVersion = $oldEngineVer

    if (-not $dryrun) {
        $newjson = ($proj | ConvertTo-Json -depth 100)
        Write-Output "Resetting .uproject"
        [System.IO.File]::WriteAllLines($pluginfile, $newjson, $Utf8NoBomEncoding)
    }


    if ($browse -and -not $dryrun) {
        Invoke-Item $config.PackageDir
    }

}
catch {
    Write-Output $_.Exception.Message
    Write-Output "~-~-~ Unreal Plugin Package FAILED ~-~-~"
    Exit 9
}

Write-Output "~-~-~ Unreal Plugin Package Completed OK ~-~-~"
