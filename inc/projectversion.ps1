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

    $gameIniFile = Get-Project-Version-Ini-Filename $srcfolder
    $gameIni = Get-IniContent $gameIniFile

    Write-Verbose "[version++] M:$major m:$minor p:$patch h:$hotfix"

    # We have to use Write-Verbose now that we're using the return value, Write-Output
    # appends to the return value. Write-Verbose works but doesn't appear by default
    # Unless user sets $VerbosePreference="Continue"

    # Bump the version number of the build
    Write-Verbose "[inc_version] Updating $gameIniFile"

    $versionString = $gameIni["/Script/EngineSettings.GeneralProjectSettings"].ProjectVersion
    Write-Verbose "[version++] Current version is $versionString"

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

        if ($major) {
            $intversions[0]++
        } elseif ($minor) {
            $intversions[1]++
        } elseif ($patch) {
            $intversions[2]++
        } else {
            $intversions[3]++
        }
        $newver = "$prefix$($intversions[0]).$($intversions[1]).$($intversions[2]).$($intversions[3])$postfix"
        Write-Verbose "[version++] Bumping version to $newver"

        if ($dryrun) {
            Write-Verbose "[version++] dryrun: not changing $gameIniFile"
        } else {
            # We don't use PsIni to write, because it can screw up some nested non-trivial properties :(
            #$gameIni["/Script/EngineSettings.GeneralProjectSettings"].ProjectVersion = $newver
            #Out-IniFile -Force -InputObject $gameIni -FilePath $gameIniFile

            $verlineregex = "ProjectVersion=$regex"
            $matches = Select-String -Path "$gameIniFile" -Pattern $verlineregex
        
            if ($matches.Matches.Count -gt 0) {
                $origline = $matches.Matches[0].Value
                $newline = "ProjectVersion=$newver"
        
                (Get-Content "$gameIniFile").replace($origline, $newline) | Set-Content "$gameIniFile"
                Write-Verbose "[version++] Success! Version is now $newver"

            } else {
                throw "[version++] Error: unable to substitute current version, unable to find '$verlineregex'"
            }


        }

        return "$newver"

    } else {
        throw "[version++] Error: unable to read current version"
    }
}

