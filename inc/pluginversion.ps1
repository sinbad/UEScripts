
function Get-NextPluginVersion {

    param (
        [string]$currentVersion,
        [bool]$major,
        [bool]$minor,
        [bool]$patch,
        [bool]$hotfix
        )

    if (($major + $minor + $patch + $hotfix) -gt 1) {
        throw "Can't set more than one of major/minor/patch/hotfix at the same time!"
    }


    # Regex features:
    # - Can read 2-4 version components but will pad with 0s up to 4 when writing
    # - captures pre- and post-fix text and retains
    $regex = "([^\d]*)(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?(.*)"
    $matches = $currentVersion | Select-String -Pattern $regex
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
        $intversions[$versionDigit]++
        for ($d = $versionDigit + 1; $d -lt $intversions.Length; $d++) {
            $intversions[$d] = 0
        }

        $newver = "$prefix$($intversions[0]).$($intversions[1]).$($intversions[2]).$($intversions[3])$postfix"
        Write-Verbose "[version++] Bumping version to $newver"

        return "$newver"

    } else {
        throw "[version++] Error: unable to read current version"
    }
}

