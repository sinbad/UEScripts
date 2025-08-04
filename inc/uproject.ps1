. $PSScriptRoot\packageconfig.ps1


function Get-Uproject-Filename {
    param (
        [string]$srcfolder,
        [PackageConfig]$config
    )

    $projfile = ""
    if ($config -and $config.ProjectFile) {
        if (-not [System.IO.Path]::IsPathRooted($config.ProjectFile)) {
            $projfile = Join-Path $srcfolder $config.ProjectFile
        } else {
            $projfile = Resolve-Path $config.ProjectFile
        }

        if (-not (Test-Path $projfile)) {
            throw "Invalid ProfileFile setting, $($config.ProjectFile) does not exist."
        }

    } else {
        # can return multiple results, pick the first one
        $matchedfile = @(Get-ChildItem -Path $srcfolder -Filter *.uproject)[0]
        $projfile = $matchedfile.FullName
    }

    # Resolve to absolute (do it here and not in join so missing file is friendlier error)
    if ($projfile) {
        return Resolve-Path $projfile
    } else {
        return $projfile
    }
}

# Read the uproject file and return as a PSCustomObject
# Haven't defined this as a custom class because we don't control it
function Read-Uproject {
    param (
        [string]$uprojectfile
    )

    # uproject is just JSON
    return (Get-Content $uprojectfile) | ConvertFrom-Json

}

function Get-UE-Version {
    param (
        # the uproject object from Read-Uproject
        [psobject]$uproject
    )

    if ($uproject.EngineAssociation) {
        $assoc = $uproject.EngineAssociation
    } else {
        # Plugin
        $assoc = $uproject.EngineVersion
    }

    # If this is a GUID "{A1234786-..}" then it's a source build, we need to resolve it via registry
    if ($assoc -and $assoc.StartsWith("{")) {
        # Look up the source dir from registry setting
        $srcdir = Get-ItemPropertyValue 'Registry::HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds' -Name $assoc
        # In source build, read Build.version JSON
        $buildverfile = Join-Path $srcdir "Engine/Build/Build.version"
        $buildjson = (Get-Content $buildverfile) | ConvertFrom-Json
        return "$($buildjson.MajorVersion).$($buildjson.MinorVersion)"
    } else {
        return $assoc
    }
}

function Get-Is-UE5 {
    param (
        # the uproject object from Read-Uproject
        [string]$ueVersion
    )

    return $ueVersion.StartsWith("5.")
}

function Get-UE-Install {
    param (
        [string]$ueVersion
    )

    # UEINSTALL env var should point at the root of the *specific version* of 
    # UE you want to use. This is mainly for use in source builds, default is
    # to build it from version number and root of all UE binary installs
    $uinstall = $Env:UEINSTALL
    # Backwards compat
    if (-not $uinstall) {
        $uinstall = $Env:UE4INSTALL
    }

    if (-not $uinstall) {
        # UEROOT should be the parent folder of all UE versions
        $uroot = $Env:UEROOT
        # Bakwards compat
        if (-not $uroot) {
            $uroot = $Env:UE4ROOT
        }
        if (-not $uroot) {
            $uroot = "C:\Program Files\Epic Games"
        } 

        # When using $ueVersion, strip off 3rd digit if any
        $regex = "(\d+\.\d+)(\.\d+)?"
        $match = $ueVersion | Select-String -Pattern $regex

        $ueVersionTrimmed = $match.Matches[0].Groups[1].Value
        
        $uinstall = Join-Path $uroot "UE_$ueVersionTrimmed"
    }

    # Test we can find RunUAT.bat
    $batchfolder = Join-Path "$uinstall" "Engine\Build\BatchFiles"
    $buildbat = Join-Path "$batchfolder" "RunUAT.bat"
    if (-not (Test-Path $buildbat -PathType Leaf)) {
        throw "RunUAT.bat missing at $buildbat : Not a valid UE install"
    }

    return $uinstall
}

function Get-UEEditorCmd {
    param (
        [string]$ueVersion,
        [string]$ueInstall
    )

    if ((Get-Is-UE5 $ueVersion)) {
        return Join-Path $ueInstall "Engine/Binaries/Win64/UnrealEditor-Cmd$exeSuffix"

    } else {
        return Join-Path $ueInstall "Engine/Binaries/Win64/UE4Editor-Cmd$exeSuffix"
    }

}

