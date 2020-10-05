# Simplify platform checks for Powershell < 6
if (-not $PSVersionTable.Platform) {
    # This is Windows-only powershell
    $global:IsWindows = $true
    $global:IsLinux = $false
    $global:IsMacOS = $false
}