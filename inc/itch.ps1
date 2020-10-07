function Release-Itch {
    param (
        [PackageConfig]$config,
        [PackageVariant]$variant,
        [string]$sourcefolder,
        [string]$version,
        [switch]$dryrun = $false
    )

    Write-Output ">>>--- Itch Upload Start ---<<<"

    $appid = $variant.ItchAppId
    $channel = $variant.ItchChannel

    if (-not $appid) {
        throw "Missing property ItchAppId in $($variant.Name)"
    }
    if (-not $channel) {
        throw "Missing property ItchChannel in $($variant.Name)"
    }

    $target = "$($appid):$channel"

    if ($dryrun) {
        Write-Output "Would have run butler command:"
        Write-Output " > butler push --userversion=$version '$sourcefolder' $target"
    } else {
        Write-Output "Releasing version $version to Itch.io at $target"
        Write-Output " Source: $sourcefolder"

        butler push --userversion=$version "$sourcefolder" $target
        if (!$?) {
            throw "Itch butler tool failed!"
        }
    }

    Write-Output ">>>--- Itch Upload Done! ---<<<"
    Write-Output ""

}