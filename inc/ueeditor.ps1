
function Close-UE-Editor {
    param (
        [string]$uprojectname,
        [bool]$dryrun
    )

    # Filter by project name in main window title, it's always called "Project - Unreal Editor"
    $ue4proc = Get-Process UE4Editor -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowTitle -like "$uprojectname*" }
    if ($ue4proc) {
        if ($dryrun) {
            Write-Output "UE4 project is currently open in editor, would have closed"
        } else {
            Write-Output "UE4 project is currently open in editor, closing..."
            $ue4proc.CloseMainWindow() > $null 
            Start-Sleep 5
            if (!$ue4proc.HasExited) {
                throw "Couldn't close UE4 gracefully, aborting!"
            }
        }
    } else {
        Write-Verbose "UE4 project is not open in editor"
    }
    Remove-Variable ue4proc

}
