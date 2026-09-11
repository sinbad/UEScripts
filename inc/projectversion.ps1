Import-Module PsIni

function Get-Project-Version-Ini-Filename {
    param (
        [string]$srcfolder
    )

    return Join-Path $srcfolder "Config/DefaultGame.ini" -Resolve
}

function Get-Project-Version {
    param (
        [string]$srcfolder
    )

    $file = Get-Project-Version-Ini-Filename $srcfolder
    $gameIni = Get-IniContent $file

    return $gameIni["/Script/EngineSettings.GeneralProjectSettings"].ProjectVersion

}
function Get-ProjectVersionComponents {
    param (
        [string]$srcfolder
    )

    $versionString = Get-Project-Version $srcfolder
    # Regex features:
    # - Can read 2-4 version components but will pad with 0s up to 4 when writing
    # - captures pre- and post-fix text and retains
    $regex = "([^\d]*)(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?(.*)"
    $matches = $versionString | Select-String -Pattern $regex
    # 1 = prefix
    # 2-5 = version number components
    # 6 = postfix

    if (($matches.Matches.Count -gt 0) -and ($matches.Matches[0].Groups.Count -eq 7)) {
        $prefix = $matches.Matches[0].Groups[1].Value
        $postfix = $matches.Matches[0].Groups[6].Value

        $intversions = $matches.Matches[0].Groups[2..5] | ForEach-Object {
            if ($_.Value -ne "") {
                [int]$_.Value
            } else {
                # We fill in the version numbers to 4 digits always
                0
            }

        }

        return New-Object PsObject -Property @{prefix=$prefix ; postfix=$postfix; digits=$intversions}
    } else {
        return New-Object PsObject -Property @{prefix="" ; postfix=""; digits=@(1,0,0,0)}
    }
}
function Write-ProjectVersionFromObject {
    param (
        [string]$srcfolder,
        [object]$versionObj,
        [bool]$dryrun = $false
        )

    $newver = "$($versionObj.prefix)$($versionObj.digits[0]).$($versionObj.digits[1]).$($versionObj.digits[2]).$($versionObj.digits[3])$($versionObj.postfix)"
    Write-Project-Version -srcfolder:$srcfolder -newversion:$newver -dryrun:$dryrun
    
}

function Write-Project-Version {
    param (
        [string]$srcfolder,
        [string]$newversion,
        [bool]$dryrun = $false
        )

        $gameIniFile = Get-Project-Version-Ini-Filename $srcfolder
    
        if ($dryrun) {
            Write-Verbose "[version] dryrun: would have set $gameIniFile version: $newversion"
        } else {
            # We don't use PsIni to write, because it can screw up some nested non-trivial properties :(
            #$gameIni["/Script/EngineSettings.GeneralProjectSettings"].ProjectVersion = $newver
            #Out-IniFile -Force -InputObject $gameIni -FilePath $gameIniFile

            $verlineregex = "ProjectVersion=.*"
            $thematches = Select-String -Path "$gameIniFile" -Pattern $verlineregex
        
            if ($thematches.Matches.Count -gt 0) {
                $origline = $thematches.Matches[0].Value
                $newline = "ProjectVersion=$newversion"
        
                (Get-Content "$gameIniFile").replace($origline, $newline) | Set-Content "$gameIniFile"
                Write-Verbose "[version++] Success! Version is now $newversion"

            } else {
                throw "[version++] Error: unable to substitute current version, unable to find '$verlineregex'"
            }


        }

}



function Get-Next-Project-Version {

    param (
        [string]$srcfolder,
        [bool]$major,
        [bool]$minor,
        [bool]$patch,
        [bool]$hotfix,
        [bool]$dryrun = $false
        )

    if (($major + $minor + $patch + $hotfix) -gt 1) {
        throw "Can't set more than one of major/minor/patch/hotfix at the same time!"
    }

    $versionobj = Get-ProjectVersionComponents $srcfolder

    $versionDigit = 2;
    if ($major) {
        $versionDigit = 0
    } elseif ($minor) {
        $versionDigit = 1
    } elseif ($patch) {
        $versionDigit = 2
    } elseif ($hotfix) {
        $versionDigit = 3
    }
    # increment then zero anything after
    $versionObj.digits[$versionDigit]++
    for ($d = $versionDigit + 1; $d -lt $versionObj.digits.Length; $d++) {
        $versionObj.digits[$d] = 0
    }

    $newver = "$($versionObj.prefix)$($versionObj.digits[0]).$($versionObj.digits[1]).$($versionObj.digits[2]).$($versionObj.digits[3])$($versionObj.postfix)"

    return "$newver"
}

function Check-Project-Version {
    param (
        [string]$srcfolder,
        [string]$newversion,
        [bool]$hotfix,
        [PackageConfig]$config
        )

    # Validate this new project version

    # Check for patch notes file if we're using that
    if (-not $hotfix -and $config.PatchNotesDir.Length -gt 0) {
        # Strip off the 4th version digit
        $regex = "([^\d]*)(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?(.*)"
        $vmatch = $newversion | Select-String -Pattern $regex
        if (($vmatch.Matches.Count -gt 0) -and ($vmatch.Matches[0].Groups.Count -gt 4)) {
            # 1 = prefix
            # 2-5 = version number components (we skip last)
            # 6 = postfix
            
            $digits = $vmatch.Matches[0].Groups[2..4] | ForEach-Object {
                if ($_.Value -ne "") {
                    [int]$_.Value
                }
                else {
                    # We fill in the version numbers to 3 digits always
                    0
                }

            }

            # x.x.x only
            $filename = "$($digits[0]).$($digits[1]).$($digits[2]).txt"

            $fullpath = Join-Path $srcfolder $config.PatchNotesDir $filename

            if (-not (Test-Path $fullpath -PathType Leaf))
            {
                throw "Missing patch notes, expected them at $fullpath"
            }

        } else {
            throw "Can't parse version number $newversion to check"
        }
    }
}