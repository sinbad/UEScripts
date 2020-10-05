function Get-UE-Install {
    param (
        [string]$ueVersion
    )

    # UE4INSTALL env var should point at the root of the *specific version* of 
    # UE4 you want to use. This is mainly for use in source builds, default is
    # to build it from version number and root of all UE4 binary installs
    $uinstall = $Env:UE4INSTALL

    if (-not $uinstall) {
        # UE4ROOT should be the parent folder of all UE versions
        $uroot = $Env:UE4ROOT
        if (-not $uroot) {
            $uroot = "C:\Program Files\Epic Games"
        } 

        $uinstall = Join-Path $uroot "UE_$ueVersion"
    }

    # Test we can find RunUAT.bat
    $batchfolder = Join-Path "$uinstall" "Engine\Build\BatchFiles"
    $buildbat = Join-Path "$batchfolder" "RunUAT.bat"
    if (-not (Test-Path $buildbat -PathType Leaf)) {
        throw "RunUAT.bat missing at $buildbat : Not a valid UE install"
    }

    return $uinstall
}
