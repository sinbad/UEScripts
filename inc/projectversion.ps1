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
            $matches = Select-String -Path "$gameIniFile" -Pattern $verlineregex
        
            if ($matches.Matches.Count -gt 0) {
                $origline = $matches.Matches[0].Value
                $newline = "ProjectVersion=$newversion"
        
                (Get-Content "$gameIniFile").replace($origline, $newline) | Set-Content "$gameIniFile"
                Write-Verbose "[version++] Success! Version is now $newversion"

            } else {
                throw "[version++] Error: unable to substitute current version, unable to find '$verlineregex'"
            }


        }

}
function Increment-Project-Version {

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

    $gameIniFile = Get-Project-Version-Ini-Filename $srcfolder

    Write-Verbose "[version++] M:$major m:$minor p:$patch h:$hotfix"

    # We have to use Write-Verbose now that we're using the return value, Write-Output
    # appends to the return value. Write-Verbose works but doesn't appear by default
    # Unless user sets $VerbosePreference="Continue"

    # Bump the version number of the build
    Write-Verbose "[inc_version] Updating $gameIniFile"

    Write-Verbose "[version++] Current version is $($versionObj.digits[0]).$($versionObj.digits[1]).$($versionObj.digits[2]).$($versionObj.digits[3])"  
    
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
    Write-Verbose "[version++] Bumping version to $newver"

    Write-Project-Version -srcfolder:$srcfolder -newversion:$newver -dryrun:$dryrun

    return "$newver"

}

