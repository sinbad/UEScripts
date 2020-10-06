function Find-Files {
    param (
        [string]$startDir,
        [string]$pattern,
        [bool]$includeByDefault,
        [array]$includeBaseNames,
        [array]$excludeBaseNames
    )

    $basenames = [System.Collections.ArrayList]::New()
    $fullpaths = [System.Collections.ArrayList]::New()
    Get-ChildItem -Path $startDir -Filter $pattern -Recurse | ForEach-Object { 
        if ($includeByDefault) {
            if ($excludeBaseNames -notcontains $_.BaseName) {
                $basenames.Add($_.BaseName) > $null 
                $fullpaths.Add($_.FullName) > $null
            }
        } else {
            if ($includeBaseNames -contains $_.BaseName) {
                $basenames.Add($_.BaseName) > $null
                $fullpaths.Add($_.FullName) > $null
            }
        }
    }

    return [PSCustomObject]@{  
        BaseNames = $basenames
        FullNames = $fullpaths
    }

}