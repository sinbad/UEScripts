function Find-File-Set {
    param (
        [string]$startDir,
        [string]$pattern,
        [bool]$includeByDefault,
        [array]$includeBaseNames,
        [array]$excludeBaseNames
    )

    $set = [System.Collections.Generic.HashSet[string]]::New()
    Get-ChildItem -Path $startDir -Filter $pattern -Recurse | ForEach-Object { 
        if ($includeByDefault) {
            if ($excludeBaseNames -notcontains $_.BaseName) {
                $set.Add($_.BaseName) > $null 
            }
        } else {
            if ($includeBaseNames -contains $_.BaseName) {
                $set.Add($_.BaseName) > $null
            }
        }
    }

    return $set

}