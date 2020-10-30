function Release-Steam {
    param (
        [PackageConfig]$config,
        [PackageVariant]$variant,
        [string]$sourcefolder,
        [string]$version,
        [switch]$dryrun = $false
    )

    Write-Output ">>>--- Steam Upload Start ---<<<"

    $appid = $variant.SteamAppId
    $depotid = $variant.SteamDepotId
    $login = $variant.SteamLogin

    if (-not $appid) {
        throw "Missing property SteamAppId in $($variant.Name)"
    }
    if (-not $depotid) {
        throw "Missing property SteamDepotId in $($variant.Name)"
    }
    if (-not $login) {
        throw "Missing property SteamLogin in $($variant.Name)"
    }


    $steamconfigdir = Join-Path (Get-Item $sourcefolder).Parent "SteamConfig"
    New-Item -ItemType Directory $steamconfigdir -Force > $null

    # Preview mode in Steam build just outputs logs so it's dryrun
    $preview = if($dryrun) { "1" } else { "0"}

    # Use the UE4 platform as Steam target
    $target = $variant.Platform

    # write app file up to depot section then fill that in as we do depots
    $appfile = "$steamconfigdir\app_build_$($appid).vdf"
    Write-Output "Creating app build config $appfile"
    Remove-Item $appfile -Force -ErrorAction SilentlyContinue
    $appfp = New-Object -TypeName System.IO.FileStream(
        $appfile,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write)
    $appstream = New-Object System.IO.StreamWriter ($appfp, [System.Text.Encoding]::UTF8)

    $appstream.WriteLine("`"appbuild`"")
    $appstream.WriteLine("{")
    $appstream.WriteLine("    `"appid`" `"$appid`"")
    $appstream.WriteLine("    `"desc`" `"$version`"")
    $appstream.WriteLine("    `"buildoutput`" `".\steamcmdbuild`"")
    # we don't set contentroot in app file, we specify in depot files
    $appstream.WriteLine("    `"setlive`" `"`"") # never try to set live
    $appstream.WriteLine("    `"preview`" `"$preview`"")
    $appstream.WriteLine("    `"local`" `"`"")
    $appstream.WriteLine("    `"depots`"")
    $appstream.WriteLine("    {")

    # Depots inline
    # Just one in this case
    $depotfilerel = "depot_${target}_${depotid}.vdf"
    $depotfile = "$steamconfigdir\$depotfilerel"
    Write-Output "Creating depot build config $depotfile"
    Remove-Item $depotfile -Force -ErrorAction SilentlyContinue
    $depotfp = New-Object -TypeName System.IO.FileStream(
        $depotfile,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write)
    $depotstream = New-Object System.IO.StreamWriter($depotfp, [System.Text.Encoding]::UTF8)
    $depotstream.WriteLine("`"DepotBuildConfig`"")
    $depotstream.WriteLine("{")
    $depotstream.WriteLine("    `"DepotID`" `"$depotid`"")
    # We'll set ContentRoot specifically for
    $depotstream.WriteLine("    `"ContentRoot`" `"$sourcefolder`"")
    $depotstream.WriteLine("    `"FileMapping`"")
    $depotstream.WriteLine("    {")
    $depotstream.WriteLine("        `"LocalPath`" `"*`"")
    $depotstream.WriteLine("        `"DepotPath`" `".`"")
    $depotstream.WriteLine("        `"recursive`" `"1`"")
    $depotstream.WriteLine("    }")
    $depotstream.WriteLine("    `"FileExclusion`" `"*.pdb`"")
    $depotstream.WriteLine("}")
    $depotstream.Close()
    $depotfp.Close()

    # Now write depot entry to in-progress app file, relative file (same folder)
    $appstream.WriteLine("        `"$depotid`" `"$depotfilerel`"")

    # Finish the app file
    $appstream.WriteLine("    }")
    $appstream.WriteLine("}")
    $appstream.Close()

    if ($dryrun) {
        Write-Output "Would have run Steam command:"
        Write-Output " > steamcmd +login $($login) +run_app_build_http $appfile +quit"
    } else {
        Write-Output "Releasing version $version to Steam ($appid)"
        steamcmd +login $($login) +run_app_build_http $appfile +quit
        if (!$?) {
            throw "Steam upload tool failed!"
        }
    }

    Write-Output ">>>--- Steam Upload Done ---<<<"
    Write-Output ""
    if (-not $dryrun) {
        Write-Output "-- Remember to release in Steamworks Admin --"
    }

}