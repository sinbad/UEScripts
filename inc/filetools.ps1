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

# Get the root package output dir for a version / variant
function Get-Package-Dir {
    param (
        [PackageConfig]$config,
        [string]$versionNumber,
        [string]$variantName
    )

    return Join-Path $config.OutputDir "$versionNumber/$variantName"
}

# Get the dir where the client build is for a packaged version / variant
# This is as Get-Package-Dir except with one extra level e.g. WindowsNoEditor
function Get-Package-Client-Dir {
    param (
        [PackageConfig]$config,
        [string]$versionNumber,
        [string]$variantName
    )

    $root = Get-Package-Dir -config:$config -versionNumber:$versionNumber -variantName:$variantName
    $variant = $config.Variants | Where-Object { $_.Name -eq $variantName } | Select-Object -First 1

    if (-not $variant) {
        throw "Unknown variant $variantName"
    }
    # Note, currently only supporting "Game" platform type, not separate client / server
    $subfolder = switch ($variant.Platform) {
        "Win32" { "WindowsNoEditor" }
        "Win64" { "WindowsNoEditor" }
        "Linux" { "LinuxNoEditor" }
        "Mac" { "MacNoEditor" }
        Default { throw "Unsupported platform $($variant.Platform)" }
    }

    return Join-Path $root $subfolder
}
