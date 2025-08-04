. $PSScriptRoot\packageconfig.ps1


function Get-Uplugin-Filename {
    param (
        [string]$srcfolder,
        [PluginConfig]$config
    )

    $projfile = ""
    if ($config -and $config.ProjectFile) {
        if (-not [System.IO.Path]::IsPathRooted($config.PluginFile)) {
            $projfile = Join-Path $srcfolder $config.PluginFile
        } else {
            $projfile = Resolve-Path $config.PluginFile
        }

        if (-not (Test-Path $projfile)) {
            throw "Invalid ProfileFile setting, $($config.PluginFile) does not exist."
        }

    } else {
        # can return multiple results, pick the first one
        $matchedfile = @(Get-ChildItem -Path $srcfolder -Filter *.uplugin)[0]
        $projfile = $matchedfile.FullName
    }

    # Resolve to absolute (do it here and not in join so missing file is friendlier error)
    if ($projfile) {
        return Resolve-Path $projfile
    } else {
        return $projfile
    }
}

function Update-UpluginUeVersion {
    param (
        [string]$srcfolder,
        [PluginConfig]$config,
        [string]$version
    )

    $pluginfile = Get-Uplugin-Filename $srcfolder $config
    $plugincontents = (Get-Content $pluginfile) | ConvertFrom-Json

    if ($version) {
        # May need to add the member
        if ($pluginContents.PSobject.Properties.name -match "EngineVersion") {
            $plugincontents.EngineVersion = $version
        } else {
            $plugincontents | Add-Member -NotePropertyName EngineVersion -NotePropertyValue $version
        }
    } else {
        # Need to remove the EngineVersion assignment
        $plugincontents = ($plugincontents | Select-Object * -ExcludeProperty EngineVersion)
    }
    $newjson = ($plugincontents | ConvertTo-Json -depth 100)
    # Need to explicitly set to UTF8, Out-File now converts to UTF16-LE??
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($pluginfile, $newjson, $Utf8NoBomEncoding)
}