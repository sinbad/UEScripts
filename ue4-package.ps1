# Packaging helper
# Bumps versions, builds, cooks, packages variants
# Put packageconfig.json in your project folder to configure
# See packageconfig_template.json
[CmdletBinding()] # Fail on unknown args
param (
    [string]$src,
    [switch]$major = $false,
    [switch]$minor = $false,
    [switch]$patch = $false,
    [switch]$hotfix = $false,
    # Don't incrememnt version
    [switch]$keepversion = $false,
    # Force move tag
    [switch]$forcetag = $false,
    # Name of variant to build (optional, uses DefaultVariants from packageconfig.json if unspecified)
    [array]$variants,
    # Testing mode; skips clean checks, tags
    [switch]$test = $false,
    # Dry-run; does nothing but report what *would* have happened
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\packageconfig.ps1
. $PSScriptRoot\inc\projectversion.ps1
. $PSScriptRoot\inc\uproject.ps1
. $PSScriptRoot\inc\ueinstall.ps1
. $PSScriptRoot\inc\ueeditor.ps1
. $PSScriptRoot\inc\filetools.ps1


function Write-Usage {
    Write-Output "Steve's UE4 packaging tool"
    Write-Output "Usage:"
    Write-Output "  ue4-package.ps1 [-src:sourcefolder] [-major|-minor|-patch|-hotfix] [-keepversion] [-force] [-variant=VariantName] [-test] [-dryrun]"
    Write-Output " "
    Write-Output "  -src          : Source folder (current folder if omitted), must contain buildconfig.json"
    Write-Output "  -major        : Increment major version i.e. [x++].0.0.0"
    Write-Output "  -minor        : Increment minor version i.e. x.[x++].0.0"
    Write-Output "  -patch        : Increment patch version i.e. x.x.[x++].0 (default)"
    Write-Output "  -hotfix       : Increment hotfix version i.e. x.x.x.[x++]"
    Write-Output "  -keepversion  : Keep current version number, doesn't tag unless -forcetag"
    Write-Output "  -forcetag     : Move any existing version tag"
    Write-Output "  -variants Name1,Name2,Name3"
    Write-Output "                : Build only named variants instead of DefaultVariants from packageconfig.json"
    Write-Output "  -test         : Testing mode, separate builds, allow dirty working copy"
    Write-Output "  -dryrun       : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help         : Print this help"
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

Write-Output "~-~-~ UE4 Packaging Helper Start ~-~-~"

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
    $config = Read-Package-Config -srcfolder:$src
    $projfile = Get-Uproject-Filename -srcfolder:$src -config:$config
    $proj = Read-Uproject $projfile
    $ueVersion = Get-UE-Version $proj
    $ueinstall = Get-UE-Install $ueVersion

    $chosenVariantNames = $config.DefaultVariants
    if ($variants) {
        $chosenVariantNames = $variants
    }
    # TODO support overriding default variants with args
    $chosenVariants = $config.Variants | Where-Object { $chosenVariantNames -contains $_.Name }

    if ($chosenVariants.Count -ne $chosenVariantNames.Count) {
        $unmatchedVariants = $chosenVariantNames | Where-Object { $chosenVariants.Name -notcontains $_ } 
        Write-Warning "Unknown variant(s) ignored: $($unmatchedVariants -join ", ")"
    }

    $maps = Find-File-Set -startDir:$(Join-Path $src "Content") -pattern:*.umap -includeByDefault:$config.CookAllMaps -includeBaseNames:$config.MapsIncluded -excludeBaseNames:$config.MapsExcluded

    Write-Output ""
    Write-Output "Project File    : $projfile"
    Write-Output "UE Version      : $ueVersion"
    Write-Output "UE Install      : $ueinstall"
    Write-Output "Output Folder   : $($config.OutputDir)"
    Write-Output "Zipped Folder   : $($config.ZipDir)"
    Write-Output ""
    Write-Output "Chosen Variants : $chosenVariantNames"
    Write-Output "Maps to Cook    : $maps"
    Write-Output ""


    if (([bool]$major + [bool]$minor + [bool]$patch + [bool]$hotfix) -eq 0) {
        $patch = $true
    }
    $versionNumber = $null
    if ($keepversion) {
        $versionNumber = Get-Project-Version $src
    } else {
        # Bump up version, passthrough options
        try {
            $versionNumber = Increment-Project-Version -srcfolder:$src -major:$major -minor:$minor -patch:$patch -hotfix:$hotfix -dryrun:$dryrun
            if (-not $dryrun -and $isGit) {
                if ($src -ne ".") { Push-Location $src }

                $verIniFile = Get-Project-Version-Ini-Filename $src
                git add "$($verIniFile)"
                if ($LASTEXITCODE -ne 0) { Exit $LASTEXITCODE }
                git commit -m "Version bump to $versionNumber"
                if ($LASTEXITCODE -ne 0) { Exit $LASTEXITCODE }

                if ($src -ne ".") { Pop-Location }
            }
        }
        catch {
            Write-Output $_.Exception.Message
            Exit 6
        }
    }
    # Keep test builds separate
    if ($test) {
        $versionNumber = "$versionNumber-test"
    }
    Write-Output "Next version will be: $versionNumber"

    # For tagging release
    # We only need to grab the main version once
    $forcearg = ""
    if ($forcetag) {
        $forcearg = "-f"
    }
    if (-not $test -and -not $dryrun) {
        if ($src -ne ".") { Push-Location $src }
        git tag $forcearg -a $versionNumber -m "Automated release tag"
        if ($LASTEXITCODE -ne 0) { Exit $LASTEXITCODE }
        if ($src -ne ".") { Pop-Location }
    }


    $editorprojname = [System.IO.Path]::GetFileNameWithoutExtension($projfile)
    Close-UE-Editor $editorprojname $dryrun

    $ueEditorCmd = Join-Path $ueinstall "Engine/Binaries/Win64/UE4Editor-Cmd$exeSuffix"
    $runUAT = Join-Path $ueinstall "Engine/Build/BatchFiles/RunUAT$batchSuffix"


    foreach ($var in $chosenVariants) {

        $outDir = Join-Path $config.OutputDir "$versionNumber/$($var.Name)"

        $argList = [System.Collections.ArrayList]@()
        $argList.Add("-ScriptsForProject=`"$projfile`"") > $null
        $argList.Add("BuildCookRun") > $null
        $argList.Add("-nocompileeditor") > $null
        #$argList.Add("-installed")  > $null # don't think we need this, seems to be detected
        $argList.Add("-nop4") > $null
        $argList.Add("-project=`"$projfile`"") > $null
        $argList.Add("-cook") > $null
        $argList.Add("-stage") > $null
        $argList.Add("-archive") > $null
        $argList.Add("-archivedirectory=`"$($outDir)`"") > $null
        $argList.Add("-package") > $null
        $argList.Add("-ue4exe=`"$ueEditorCmd`"") > $null
        if ($config.UsePak) {
            $argList.Add("-pak") > $null
        }
        $argList.Add("-prereqs") > $null
        $argList.Add("-nodebuginfo") > $null
        $argList.Add("-build") > $null
        $argList.Add("-target=$($config.Target)") > $null
        $argList.Add("-clientconfig=$($var.Configuration)") > $null
        $argList.Add("-targetplatform=$($var.Platform)") > $null
        $argList.Add("-utf8output") > $null
        if ($maps.Count) {
            $argList.Add("-Map=$($maps -join "+")") > $null
        }
        $argList.Add($var.ExtraBuildArguments) > $null

        Write-Output "Building variant:  $($var.Name)"

        if ($dryrun) {
            Write-Output "Would have run:"
            Write-Output "> $runUAT $($argList -join " ")"

        } else {            
            $proc = Start-Process $runUAT $argList -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -ne 0) {
                throw "RunUAT failed!"
            }

        }
    }

}
catch {
    Write-Output $_.Exception.Message
    Write-Output "~-~-~ UE4 Packaging Helper FAILED ~-~-~"
    Exit 9
}


Write-Output "~-~-~ UE4 Packaging Helper Completed OK ~-~-~"
