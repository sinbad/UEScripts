[CmdletBinding()] # Fail on unknown args
param (
    # Version to release
    [Parameter(Mandatory=$true)]
    [string]$version,
    # Variant name to release
    [Parameter(Mandatory=$true)]
    # Project folder (assumes current dir if not specified)
    [string]$variant,
    # Source folder, current dir if omitted
    [string]$src,
    # Which service(s) to release on e.g. "steam": defaults to "ReleaseTo" services in packageconfig.json for variant 
    [array]$services,
    # Dry-run; does nothing but report what *would* have happened
    [switch]$dryrun = $false,
    [switch]$help = $false
)

. $PSScriptRoot\inc\platform.ps1
. $PSScriptRoot\inc\packageconfig.ps1
. $PSScriptRoot\inc\filetools.ps1
. $PSScriptRoot\inc\steam.ps1
. $PSScriptRoot\inc\itch.ps1


function Write-Usage {
    Write-Output "Steve's UE4 release tool"
    Write-Output "Usage:"
    Write-Output "  ue4-release.ps1 -version:ver -variant:var -services:steam,itch [-src:sourcefolder] [-dryrun]"
    Write-Output " "
    Write-Output "  -version:ver    : Version to release; must have been packaged already"
    Write-Output "  -variant:var    : Name of package variant to release"
    Write-Output "  -services:s1,s2 : Name of services to release to. Can omit and rely on ReleaseTo"
    Write-Output "                    setting of variant in packageconfig.json "
    Write-Output "  -src            : Source folder (current folder if omitted), must contain packageconfig.json"
    Write-Output "  -dryrun         : Don't perform any actual actions, just report what would happen"
    Write-Output "  -help           : Print this help"
}

$ErrorActionPreference = "Stop"

if ($help) {
    Write-Usage
    Exit 0
}

if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}

Write-Output "~-~-~ UE4 Release Helper Start ~-~-~"

try {

    # Import config
    $config = Read-Package-Config -srcfolder:$src

    # Find variant (first match in case config has many)
    $variantConfig = $config.Variants | Where-Object { $_.Name -eq $variant }
    if ($variantConfig -is [array]) {
        if ($variantConfig.Count > 1) {
            throw "More than one package variant called $variant in packageconfig.json, ambiguous!"
        } else {
            # Don't think this will happen but still
            $variantConfig = $variantConfig[0]
        }
    }

    # Get source dir
    $sourcedir = Get-Package-Client-Dir -config:$config -versionNumber:$version -variantName:$variant

    if (-not (Test-Path $sourcedir -PathType Container)) {
        throw "Release folder $sourcedir does not exist"
    }

    # Find service(s)
    if ($services) {
        # Release to a subset of allowed services
        $servicesFound = $services | Where-Object {$variantConfig.ReleaseTo -contains $_ }
        if ($servicesFound.Count -ne $services.Count) {
            $unmatchedServices = $services | Where-Object { $servicesFound -notcontains $_ } 
            Write-Warning "Services(s) not supported by $($variantConfig.Name): $($unmatchedServices -join ", ")"
        }
    } else {
        $servicesFound = $variantConfig.ReleaseTo
    }

    if (-not $servicesFound) {
        throw "No matching services to release $variant to"
    }

    Write-Output ""
    Write-Output "Variant         : $variant"
    Write-Output "Source Folder   : $sourcedir"
    Write-Output "Service(s)      : $($servicesFound -join ", ")"
    Write-Output ""


    foreach ($service in $servicesFound) {
        if ($service -eq "steam") {
            Release-Steam -config:$config -variant:$variantConfig -sourcefolder:$sourcedir -version:$version -dryrun:$dryrun
        } elseif ($service -eq "itch") {
            Release-Itch -config:$config -variant:$variantConfig -sourcefolder:$sourcedir -version:$version -dryrun:$dryrun
        } else {
            throw "Unknown release service: $service"
        }
    }

} catch {
    Write-Output $_.Exception.Message
    Write-Output "~-~-~ UE4 Release Helper FAILED ~-~-~"
    Exit 9
}


Write-Output "~-~-~ UE4 Release Helper Completed OK ~-~-~"
