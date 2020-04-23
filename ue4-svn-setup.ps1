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
    Write-Output "  Run this if you already have a SVN trunk checkout"
    Write-Output "Usage:"
    Write-Output "  ue4-svn-setup.ps1 [[-src:]sourcefolder] [Options]"
    Write-Output " "
    Write-Output "  -src         : Source folder (current folder if omitted)"
    Write-Output "               : (should be root of trunk in new repo)"
    Write-Output "  -skipstructurecheck"
    Write-Output "               : Skip the check that makes sure you're in trunk"
    Write-Output "  -overwriteprops"
    Write-Output "               : Replace all properties instead of merging"
    Write-Output "               : Will overwrite svn:ignore, svn:global-ignores, svn:auto-props"
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
*.tga = svn:needs-lock=*
*.dds = svn:needs-lock=*
*.exr = svn:needs-lock=*
*.uasset = svn:needs-lock=*
*.umap = svn:needs-lock=*
*.mlt = svn:needs-lock=*
*.blend = svn:needs-lock=*
*.fbx = svn:needs-lock=*
*.afphoto = svn:needs-lock=*
*.afdesign = svn:needs-lock=*
*.aup = svn:needs-lock=*
*.mp3 = svn:needs-lock=*
*.wav = svn:needs-lock=*
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

$content_folders = @"
Content/
Content/Animation
Content/Audio
Content/Audio/FX
Content/Audio/Music
Content/Blueprints
Content/Blueprints/UI
Content/Fonts
Content/Maps
Content/Materials
Content/Meshes
Content/Particles
Content/Textures
Content/Textures/UI
"@

$mediasrc_folders = @"
MediaSrc
MediaSrc/Audio
MediaSrc/Audio/FX
MediaSrc/Audio/Music
MediaSrc/Meshes
MediaSrc/Textures
MediaSrc/Textures/UI
"@

function Set-Svn-Props {

    param (
        [string]$propname,
        [string]$values,
        [string]$path
        )

    if (-not $overwriteprops) {
        # We need to merge our props with whatever is already present
        # Can't believe SVN doesn't have a command for this (facepalm)
        # We need to continue on error if property doesn't exist
        $ErrorActionPreference = "SilentlyContinue"
        $oldvalues = (svn propget $propname $path 2>$null)
        $ErrorActionPreference = "Stop"
        $oldarray = $oldvalues -split "\r?\n"
        $newarray = $values -split "\r?\n"
        # remove duplicates & Empties and sort both arrays so we can insert
        $oldarray = $oldarray | Where-Object {$_} | Select-Object -Unique | Sort-Object
        $newarray = $newarray | Where-Object {$_} | Select-Object -Unique | Sort-Object
        # create modifiable list for merged
        $finallist = [System.Collections.ArrayList]@()
        $oldidx = 0
        foreach ($newitem in $newarray) {
            # If this is a X = Y row, then we only match the X part
            $match = $newitem
            $iskeyvalue = $($newitem -contains "=")
            if ($iskeyvalue) {
                $match = $newitem.split("=")[0].trim()
            }

            $insertednewitem = $false
            while (-not $insertednewitem) {
                if ($oldidx -lt $oldarray.Length) {
                    $olditem = $oldarray[$oldidx]
                    $oldmatch = $olditem
                    if ($iskeyvalue) {
                        $oldmatch = $olditem.split("=")[0].trim()
                    }

                    if ($match -eq $oldmatch) {
                        # use new value
                        $finallist.Add($newitem) > $null # ArrayList.Add returns index & prints it
                        ++$oldidx
                        $insertednewitem = $true
                    } elseif ($match -gt $oldmatch) {
                        $finallist.Add($olditem) > $null
                        ++$oldidx
                    } else {
                        $finallist.Add($newitem) > $null
                        $insertednewitem = $true
                    }
                } else {
                    # run out of old items, just append new
                    $finallist.Add($newitem) > $null
                    $insertednewitem = $true
                }
            }
        }
        while ($oldidx -lt $oldarray.Length) {
            ## Add any trailing old items
            $finallist.Add($oldarray[$oldidx++])
        }

        # Convert to final values
        $values = $($finallist -join "`n")
        
        Write-Verbose "Merged values for $propname on '$path': `n$values"
    }

    if ($dryrun) {
        Write-Output "PROPS: Would have set $propname on '$path' to: `n$values"
    } else {
        svn propset $propname "$values" $path
    }


}

function Create-Svn-Folder {
    param (
        [string]$fld
        )

        if (-not $(Test-Path $fld)) {
        Write-Output "FIXED: $fld folder did not exist, creating"
        if (-not $dryrun) {
            New-Item -Path $fld -ItemType Directory > $null
        }
    }
    
    $statline = svn status -v --depth=empty $fld
    if ($statline) {
        $status = $statline[0]
    } else {
        $status = '?'
    }
    if ($status -eq 'I' -or $status -eq '?') {
        Write-Output "FIXED: $fld directory is not tracked in SVN, adding"
        if (-not $dryrun) {
            # Add but don't add any contents yet because we may need to ignore them
            svn add --depth=empty $fld > $null
        }
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


try {
    # Create Content & subfolders of Content so that they already exist & properties work
    foreach ($cf in $content_folders -split "\r?\n") {
        Create-Svn-Folder $cf
    }
    foreach ($msf in $mediasrc_folders -split "\r?\n") {
        Create-Svn-Folder $msf
    }


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



if ($src -ne ".") { Pop-Location }
