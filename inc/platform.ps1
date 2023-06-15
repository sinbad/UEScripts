# Simplify platform checks for Powershell < 6
if (-not $PSVersionTable.Platform) {
    # This is Windows-only powershell
    $global:IsWindows = $true
    $global:IsLinux = $false
    $global:IsMacOS = $false
}


$exeSuffix = ""
$batchSuffix = ".sh"
if ($IsWindows) {
    $exeSuffix = ".exe"
}
if ($IsWindows) {
    $batchSuffix = ".bat"
}


function Get-Platform {
    if ($IsWindows) {
        return "Win64"
    } elseif ($IsLinux) {
        return "Linux"
    } else {
        return "Mac"
    }
}
