function Find-DefaultTarget {
    param (
        [string]$srcfolder,
        # Game, Editor, Server, Client
        [string]$preferred = "Editor"
    )

    # Enumerate the Target.cs files in Source folder and use the default one
    # This lets us not assume what the modules are called exactly
    $targetFiles = Get-ChildItem (Join-Path $srcfolder "Source" "*.Target.cs")

    foreach ($file in $targetfiles) {
        if ($file.Name -like "*$preferred.Target.cs") {
            return $file.Name.SubString(0, $file.Name.Length - 10)
        }
    }

    # Fall back on Game if nothing else
    foreach ($file in $targetfiles) {
        if ($file.Name -like "*Game.Target.cs") {
            return $file.Name.SubString(0, $file.Name.Length - 10)
        }
    }

    throw "Unable to find default build target ending in $preferred"

}
