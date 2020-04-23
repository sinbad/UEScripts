[CmdletBinding()] # Fail on unknown args
param (
    [string]$url,
    [string]$path,
    [switch]$help = $false
)

function Print-Usage {
    Write-Output "Steve's UE4 Subversion Repo Creation Tool"
    Write-Output "  Create the structure for a new SVN repo & setup for UE4"
    Write-Output "  It will create trunk/branches/tags, then checkout trunk & setup UE4"
    Write-Output "  Run this if you have a completely blank server side repo & no checkout"
    Write-Output "Usage:"
    Write-Output "  ue4-svn-create.ps1 [-urn:]svnurl [[-path:]checkoutpath] [Options]"
    Write-Output " "
    Write-Output "  -url         : Subversion URL; the ROOT path (should be empty)"
    Write-Output "  -path        : Checkout path; if omitted append last part of URL to current dir"
    Write-Output "  -help        : Print this help"
}

function Delete-Recursive {
    param (
        [string]$pathtodelete
    )
    # Remove-Item -Recurse doesn't work properly so do this manually
    # -Force to Get-ChildItem includes hidden files, -Force to Remove-Item allows readonly delete
    Get-ChildItem $pathtodelete -Recurse -Force | Remove-Item -Force -Recurse
    Remove-Item -Force $pathtodelete # remove parent too
    
}


if ($help) {
    Print-Usage
    Exit 0
}

if ($url.Length -eq 0) {
    Write-Output "ERROR: Missing Subversion URL argument"
    Exit 1
}

$ErrorActionPreference = "Stop"

# Parse URL
$svnurl = [uri]$url

if ($path.Length -eq 0) {
    $path = $svnurl.Segments[$svnurl.Segments.Length-1]
    Write-Verbose "INFO: Checkout path not specified, using '$path'"
}

# Check $path doesn't exist
if (Test-Path $path) {
    Write-Output "ERROR: Directory at '$path' already exists"
    Exit 2
}

# Checkout SVN root
Write-Output "Checking out $url to $path"
svn checkout $url $path > $null

Push-Location $path

# check empty
if ($(Get-ChildItem .).Length -gt 0) {
    # it's OK if the contents are trunk/branches/tags
    # .svn is not listed by default since hidden but allow anyway
    $allowed = @("trunk", "branches", "tags", ".svn")
    foreach ($sub in $(Get-ChildItem .)) {
        if (-not $sub -in $allowed) {
            Write-Output "ERROR: Subversion root is not empty (bad entry: '$sub')"
            Pop-Location
            Delete-Recursive $path
            Exit 2
        }
    }
}

Write-Output "Creating trunk/branches/tags folders"

$commit = $false
foreach ($dir in @("trunk", "branches", "tags")) {
    if (-not $(Test-Path trunk)) {
        New-Item $dir -ItemType Directory > $null
        svn add $dir > $null
        $commit = $true
    }
}
if ($commit) {
    svn commit -m "Created basic trunk/branches/tags structure"
}

Pop-Location

# Now delete and checkout trunk
Delete-Recursive $path
svn checkout $url/trunk $path > $null

Push-Location $path

# Call setup script from our location
& $PSScriptRoot/ue4-svn-setup.ps1

# That doesn't commit, so do that now
svn commit -m "UE4 setup for Subversion" > $null

Pop-Location



