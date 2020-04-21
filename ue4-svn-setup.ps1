[CmdletBinding()] # Fail on unknown args
param (
    [string]$src,
    # Ignore project structure problems
    [switch]$skipstructurecheck = $false,
    [switch]$overwriteprops = $false,
    [switch]$dryrun = $false,
    [switch]$help = $false
)

function Print-Usage {
    Write-Output "Steve's UE4 Subversion Repo Setup Tool"
    Write-Output "Usage:"
    Write-Output "  ue4-svn-setup.ps1 [-src:sourcefolder] [-skipstructurecheck]"
    Write-Output " "
    Write-Output "  -src         : Source folder (current folder if omitted)"
    Write-Output "               : (should be root of trunk in new repo)"
    Write-Output "  -skipstructurecheck"
    Write-Output "               : Skip the check that makes sure you're in trunk"
    Write-Output "  -overwriteprops"
    Write-Output "               : Replace all properties instead of merging"
    Write-Output "               : Will overwrite svn:ignore, svn:global-ignores"
    Write-Output "  -dryrun      : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help        : Print this help"
}

$root_svnignore = @"
.vs
Binaries
Build
DerivedDataCache
Intermediate
Saved
"@

$content_globalignores = @"
*.bmp
*.png
*.jpg
*.tif
*.tiff
*.tga
*.fbx
*.exr
*.mp3
*.wav
"@

$root_autoprops = @"
*.bmp = svn:mime-type=image/bmp;svn:needs-lock=*
*.gif = svn:mime-type=image/gif;svn:needs-lock=*
*.ico = svn:mime-type=image/x-icon;svn:needs-lock=*
*.jpeg = svn:mime-type=image/jpeg;svn:needs-lock=*
*.jpg = svn:mime-type=image/jpeg;svn:needs-lock=*
*.png = svn:mime-type=image/png;svn:needs-lock=*
*.tif = svn:mime-type=image/tiff;svn:needs-lock=*
*.tiff = svn:mime-type=image/tiff;svn:needs-lock=*    
*.uasset = svn:needs-lock=*
*.umap = svn:needs-lock=*
*.mlt = svn:needs-lock=*
*.blend = svn:needs-lock=*
*.afphoto = svn:needs-lock=*
*.afdesign = svn:needs-lock=*
*.doc = svn:mime-type=application/x-msword;svn:needs-lock=*
*.docx = svn:mime-type=application/x-msword;svn:needs-lock=*
*.jar = svn:mime-type=application/octet-stream;svn:needs-lock=*
*.odc = svn:mime-type=application/vnd.oasis.opendocument.chart;svn:needs-lock=*
*.odf = svn:mime-type=application/vnd.oasis.opendocument.formula;svn:needs-lock=*
*.odg = svn:mime-type=application/vnd.oasis.opendocument.graphics;svn:needs-lock=*
*.odi = svn:mime-type=application/vnd.oasis.opendocument.image;svn:needs-lock=*
*.odp = svn:mime-type=application/vnd.oasis.opendocument.presentation;svn:needs-lock=*
*.ods = svn:mime-type=application/vnd.oasis.opendocument.spreadsheet;svn:needs-lock=*
*.odt = svn:mime-type=application/vnd.oasis.opendocument.text;svn:needs-lock=*
*.pdf = svn:mime-type=application/pdf;svn:needs-lock=*
*.ppt = svn:mime-type=application/vnd.ms-powerpoint;svn:needs-lock=*
*.ser = svn:mime-type=application/octet-stream;svn:needs-lock=*
*.swf = svn:mime-type=application/x-shockwave-flash;svn:needs-lock=*
*.vsd = svn:mime-type=application/x-visio;svn:needs-lock=*
*.xls = svn:mime-type=application/vnd.ms-excel;svn:needs-lock=*
*.zip = svn:mime-type=application/zip;svn:needs-lock=*
"@


function Set-Svn-Props {

    param (
        [string]$propname,
        [string]$values,
        [string]$path
        )

    # TODO implement merge
    if ($dryrun) {
        Write-Output "PROPS: Would have set $propname on '$path' to: `n$values"
    } else {
        svn propset $propname "$values" $path
    }


}

if ($help) {
    Print-Usage
    Exit 0
}

if ($src.Length -eq 0) {
    $src = "."
    Write-Verbose "-src not specified, assuming current directory"
}

$ErrorActionPreference = "Stop"

if ($src -ne ".") { 
    Push-Location $src
    if ($LASTEXITCODE -ne 0) {
        Write-Output "ERROR: Unable to change directory to '$src', exiting"
        Exit 1
    }
}

$svnurl = svn info --show-item 'url'
if ($LASTEXITCODE -ne 0) {
    Write-Output "ERROR: 'svn info' failed, not a Subversion repository?'"
    Exit 1
}

if (-not $skipstructurecheck) {
    # check that we're in the trunk folder, if not, stop & warn about project structure (disable with option)
    $svnleaf = Split-Path -Path $svnurl -Leaf
    if ($svnleaf -ne "trunk") {
        Write-Output "ERROR: SVN URL $svnurl is not at the root of trunk"
        Exit 1
    }
    Write-Verbose "SVN URL is $svnurl, all OK"
}

# Make sure Content exists & is already under version control and if not, add
if (-not $(Test-Path Content)) {
    Write-Output "FIXED: Content folder did not exist, creating"
    if (-not $dryrun) {
        New-Item -Path Content -ItemType Directory
    }

}

$statline = svn status -v --depth=empty Content
if ($statline) {
    $status = $statline[0]
} else {
    $status = '?'
}
if ($status -eq 'I' -or $status -eq '?') {
    Write-Output "Content directory is not tracked in SVN, adding"
    if (-not $dryrun) {
        # Add but don't add any contents yet because we'll need to ignore them
        # We're creating this because it needs to be added to SVN to add ignores!
        svn add --depth=empty Content
    }
}

try {
    # Ignore root folders we don't need
    Set-Svn-Props "svn:ignore" $root_svnignore "."

    # Globally ignore non .uasset files inside Content
    # Because we'll put all source files in MediaSource and export into Content for UE import
    # We don't need both the exported version and the uasset
    # We'll use the svn 1.8+ global-ignores inherited property so it applies to all subfolders created later
    # Regular ignore even with --recursive only sets on folders that exist already
    Set-Svn-Props "svn:global-ignores" $content_globalignores "Content"

    # Now set up svn:needs-lock in auto-props
    Set-Svn-Props "svn:auto-props" $root_autoprops "."

} catch {
    Write-Output $_.Exception.Message
    Exit 9
}



# TODO create/add common subfolders of Content so that they already exist & svn:global-ignores work



if ($src -ne ".") { Pop-Location }
