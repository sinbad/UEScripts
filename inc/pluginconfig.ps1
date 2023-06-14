

class PluginConfig {
    [string]$OutputDir
    [string]$PluginFile
    [array]$EngineVersions

    PluginConfig([PSCustomObject]$obj) {
        # Construct from JSON object

        # Override just properties that are set
        $obj.PSObject.Properties | ForEach-Object {
            try {
                # Nested array dealt with below
                $this.$($_.Name) = $_.Value
            } catch {
                Write-Host "Invalid property in plugin config: $($_.Name) = $($_.Value)"
            }
        }

    }
    
    
}

# Read pluginconfig.json file from a source location and return PluginConfig instance
function Read-Plugin-Config {
    param (
        [string]$srcfolder
    )

    $configfile = Resolve-Path "$srcfolder\pluginconfig.json"
    if (-not (Test-Path $configfile -PathType Leaf)) {
        throw "$srcfolder\pluginconfig.json does not exist!"
    }

    $obj = (Get-Content $configfile) | ConvertFrom-Json

    return [PluginConfig]::New($obj)

}
