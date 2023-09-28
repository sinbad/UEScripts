# How Scripts Locate the Unreal Install

If you're using an installed version of Unreal, the script reads your project file
and automatically finds the location of the tools.

If you're using a source version of UE, or have installed in a non-standard location,
you can define the following environment variables instead:

* **UEROOT** : Set the root directory of installed versions of Unreal (instead of the default e.g. C:\Program Files\Epic Games). The script will find the correct version in subfolders e.g. UE_4.27, UE_5.0
* **UEINSTALL**: Explicitly set the location of the Unreal build you want to use.
    The script will just use this directly and assume that the folder it points to on disk contains e.g. Engine/Build/BatchFiles


