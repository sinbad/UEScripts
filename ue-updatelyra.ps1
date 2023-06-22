[CmdletBinding()] # Fail on unknown args
param (
    [string]$src,
    [string]$dest,
    [string]$mainbranch = "main",
    [string]$upstreambranch = "lyra-upstream",
    [string]$custombranch = "lyra-custom",
    [switch]$dryrun = $false,
    [switch]$help = $false
)

function Print-Usage {
    Write-Output "Steve's Lyra Update Tool"
    Write-Output "Usage:"
    Write-Output "  ue-updatelyra.ps1 [-src:]sourcefolder [-dest:destfolder] [Options]"
    Write-Output " "
    Write-Output "  -src            : Source Lyra folder"
    Write-Output "                  : Folder created by Create Project on Lyra in Marketplace"
    Write-Output "  -dest           : Destination folder (default: current directory)"
    Write-Output "                  : Must be root folder of your custom Lyra based project"
    Write-Output "  -mainbranch     : Name of main branch (default main)"
    Write-Output "  -upstreambranch : Name of branch containing pristine upstream version of Lyra (default lyra-upstream)"
    Write-Output "                  : (MUST exist! We need to know where the pristine Lyra goes)"
    Write-Output "  -custombranch   : Name of branch with your custom changes to Lyra (default lyra-custom)"
    Write-Output "                  : (Will be created if missing)"
    Write-Output "  -dryrun         : Don't perform any actual actions, just report on what you would do"
    Write-Output "  -help           : Print this help"
    Write-Output " "

}

$ErrorActionPreference = "Stop"

if ($help) {
    Print-Usage
    Exit 0
}

if ($src.Length -eq 0) {
    Write-Output "Error: Source directory argument is mandatory"
    Print-Usage
    Exit 3
}

if ($dest.Length -eq 0) {
    $dest = "."
    Write-Verbose "dest not specified, assuming current directory"
}

# Detect Git
if ($dest -ne ".") { Push-Location $dest }
$isGit = Test-Path ".git"
if ($dest -ne ".") { Pop-Location }

if (-not $isGit)
{
    Write-Output "Destination '$dest' is not a Git repo, cannot continue!"
    Exit 3
}
# Check that source contains Lyra
if (-not (Test-Path (Join-Path $src "LyraStarterGame.uproject")))
{
    Write-Output "Source folder '$src' does not contain LyraStarterGame.uproject"
    Exit 3
}
# Check that destination contains Lyra
if (-not (Test-Path (Join-Path $dest "LyraStarterGame.uproject")))
{
    Write-Output "Destination folder '$dest' does not contain LyraStarterGame.uproject"
    Exit 3
}
# Check that source & destination are not the same (no standardise path in ps, Join-Path does it)
if ((Join-Path (Resolve-Path $dest) "") -eq (Join-Path (Resolve-Path $src) ""))
{
    Write-Output "Source and destination folder point to the same location, $src"
    Exit 3
}

# Check working copy is clean
if ($dest -ne ".") { Push-Location $dest }

if (Test-Path ".git") {
    git diff --no-patch --exit-code
    if ($LASTEXITCODE -ne 0) {
        Write-Output "Working copy is not clean (unstaged changes)"
        if ($dryrun) {
            Write-Output "dryrun: Continuing but this will fail without -dryrun"
        } else {
            Exit $LASTEXITCODE
        }
    }
    git diff --no-patch --cached --exit-code
    if ($LASTEXITCODE -ne 0) {
        Write-Output "Working copy is not clean (staged changes)"
        if ($dryrun) {
            Write-Output "dryrun: Continuing but this will fail without -dryrun"
        } else {
            Exit $LASTEXITCODE
        }
    }
}


git rev-parse --verify -q $upstreambranch > $null
if ($LASTEXITCODE -ne 0)
{
    Write-Output "Missing Lyra upstream branch '$upstreambranch'"
    Exit 3
}
git rev-parse --verify -q $mainbranch > $null
if ($LASTEXITCODE -ne 0)
{
    Write-Output "Missing main branch '$mainbranch'"
    Exit 3
}


if ($dryrun)
{
    Write-Output "Would have run:"
}

# Switch to lyra pristine branch
if ($dryrun)
{
    Write-Output " > git checkout $upstreambranch"
}
else 
{
    git checkout $upstreambranch
}

# Check that dest contains Lyra
if (-not (Test-Path (Join-Path $dest "LyraStarterGame.uproject")))
{
    Write-Output "Destination folder '$dest' does not contain LyraStarterGame.uproject after checking out $upstreambranch"
    Exit 3
}

try {
    # Copy Lyra source
    # Use robocopy -mir so that we delete files that are missing in source

    $argList = [System.Collections.ArrayList]@()
    $argList.Add($src) > $null
    $argList.Add($dest) > $null
    # Mirror (deletes)
    $argList.Add("/mir") > $null
    # Allow resume
    $argList.Add("/z") > $null
    # Wait time for retry
    $argList.Add("/w:3") > $null
    # Exclude git files / dirs (do not delete because of mirroring)
    $argList.Add("/xf") > $null
    $argList.Add((Join-Path $dest ".gitignore")) > $null
    $argList.Add("/xf") > $null
    $argList.Add((Join-Path $dest ".gitattributes")) > $null
    $argList.Add("/xf") > $null
    $argList.Add((Join-Path $dest ".gitmodules")) > $null
    $argList.Add("/xd") > $null
    $argList.Add((Join-Path $dest ".git")) > $null
    # Exclude source Intermediate, Binaries, DDC
    $argList.Add("/xd") > $null
    $argList.Add((Join-Path $src "Binaries")) > $null
    $argList.Add("/xd") > $null
    $argList.Add((Join-Path $src "Intermediate")) > $null
    $argList.Add("/xd") > $null
    $argList.Add((Join-Path $src "DerivedDataCache")) > $null

    if ($dryrun) {
        Write-Output " > robocopy $($argList -join " ")"

    } else {            
        $proc = Start-Process "robocopy" $argList -Wait -PassThru -NoNewWindow
        # Robocopy can return up to value 8 for success
        # See https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy
        if ($proc.ExitCode -gt 8) {
            throw "robocopy failed!"
        }    
    }


    # Add & Commit changes, if any
    if (-not $dryrun)
    {
        git add .
        git diff --no-patch --cached --exit-code
        if ($LASTEXITCODE -eq 0) {
            Write-Output "No changes found to Lyra"
            git checkout $mainbranch
            Exit 0
        }
        git commit -m "Lyra update"
    } 
    else 
    {
        Write-Output " > git add . && git commit -m `"Lyra update`""
    }


    if (-not $dryrun)
    {
        # Merge changes into custom
        git rev-parse --verify -q $custombranch > $null
        if ($LASTEXITCODE -ne 0)
        {
            Write-Output "Creating branch '$custombranch'"
            git checkout -b $custombranch
        }
        else
        {
            git checkout $custombranch
            git merge $upstreambranch
            if ($LASTEXITCODE -ne 0)
            {
                throw "Unable to merge $upstreambranch into $custombranch, resolve merge conflicts and finish merge into $mainbranch yourself "
            }
        }

        # merge changes into main branch
        git checkout $mainbranch
        git merge $custombranch
        if ($LASTEXITCODE -ne 0)
        {
            throw "Unable to merge $upstreambranch into $custombranch, resolve merge conflicts and finish merge into $mainbranch yourself "
        }
    

    }
    else 
    {
        Write-Output " > git checkout $custombranch"
        Write-Output " > git merge $upstreambranch"
        Write-Output " > git checkout $mainbranch"
        Write-Output " > git merge $custombranch"

    }



}
catch {
    if ($dest -ne ".") { Pop-Location }
    Write-Output $_.Exception.Message
    Write-Output "~-~-~ Updating Lyra FAILED ~-~-~"
    Exit 9
}

if ($dest -ne ".") { Pop-Location }
Write-Output "~-~-~ Lyra Update Completed OK ~-~-~"







