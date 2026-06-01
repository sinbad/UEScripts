# PSScriptRoot is relative to this file, not the calling file
. $PSScriptRoot\buildtargets.ps1
. $PSScriptRoot\uproject.ps1


function Build-Project {
    
    param (
        [string]$mode,
        [string]$src,
        [switch]$nocloseeditor = $false,
        [switch]$dryrun = $false
    )

    if (-not $mode) {
        $mode = "dev"
    }

    if ($src.Length -eq 0) {
        $src = "."
        Write-Verbose "-src not specified, assuming current directory"
    }

    if (-not ($mode -in @('dev', 'cleandev', 'test', 'prod'))) {
        Print-Usage
        Write-Information "ERROR: Invalid mode argument: $mode"
        Exit 3

    }

    $result = 0

    try {
        if ($src -ne ".") { Push-Location $src }

        Write-Information "-- Build process starting --"

        # Locate Unreal project file
        $uprojfile = Get-ChildItem *.uproject | Select-Object -expand Name
        if (-not $uprojfile) {
            throw "No Unreal project file found in $(Get-Location)! Aborting."
        }
        if ($uprojfile -is [array]) {
            throw "Multiple Unreal project files found in $(Get-Location)! Aborting."
        }

        # In PS 6.0+ we could use Split-Path -LeafBase but let's stick with built-in PS 5.1
        $uprojname = [System.IO.Path]::GetFileNameWithoutExtension($uprojfile)
        if ($dryrun) {
            Write-Information "Would build $uprojname for $mode"
        } else {
            Write-Information "Building $uprojname for $mode"
        }

        $uproject = Read-Uproject $uprojfile
        $uversion = Get-UE-Version $uproject
        $uinstall = Get-UE-Install $uversion

        Write-Information "Engine version is $uversion"


        $buildargs = ""

        switch ($mode) {
            'dev' {
                # Stolen from the VS project settings because boy is this badly documented
                # The -Project seems to be needed, as is the -FromMsBuild
                # -Project has to point at the ABSOLUTE PATH of the uproject
                $uprojfileabs = Join-Path "$(Get-Location)" $uprojfile
                $target = Find-DefaultTarget $src "Editor"
                $buildargs = "$target Win64 Development -Project=`"${uprojfileabs}`" -WaitMutex -FromMsBuild"
            }
            'cleandev' {
                $uprojfileabs = Join-Path "$(Get-Location)" $uprojfile
                $target = Find-DefaultTarget $src "Editor"
                $buildargs = "$target Win64 Development -Project=`"${uprojfileabs}`" -WaitMutex -FromMsBuild -clean"
            }
            'test' {
                $uprojfileabs = Join-Path "$(Get-Location)" $uprojfile
                $target = Find-DefaultTarget $src "Game"
                $buildargs = "$target Win64 Test -Project=`"${uprojfileabs}`" -WaitMutex -FromMsBuild -clean"
            }
            'prod' {
                $uprojfileabs = Join-Path "$(Get-Location)" $uprojfile
                $target = Find-DefaultTarget $src "Game"
                $buildargs = "$target Win64 Shipping -Project=`"${uprojfileabs}`" -WaitMutex -FromMsBuild -clean"
            }
            default {
                # TODO
                # We probably want to use custom launch profiles for this
                Write-Information "Mode '$mode' is not supported yet"
            }
        }

        # Test we can find Build.bat
        $batchfolder = Join-Path "$uinstall" "Engine\Build\BatchFiles"
        $buildbat = Join-Path "$batchfolder" "Build.bat"
        if (-not (Test-Path $buildbat -PathType Leaf)) {
            throw "Build.bat missing at $buildbat : Aborting"
        }

        if ($dryrun) {
            Write-Information "Would run: build.bat $buildargs"
        } else {
            Write-Verbose "Running $buildbat $buildargs"

            $proc = Start-Process $buildbat $buildargs -Wait -PassThru -NoNewWindow
            if ($proc.ExitCode -ne 0) {
                $code = $proc.ExitCode
                throw "*** Build exited with code $code, see above"
            }
        }

        Write-Information "-- Build process finished OK --"

    } catch {
            Write-Information "ERROR: $($_.Exception.Message)"
            $result = 9
    } finally {
        if ($src -ne ".") { Pop-Location }
    }
    
    return $result
}

