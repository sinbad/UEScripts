# How Scripts Locate the UE4 Install

If you're using an installed version of UE4, the script reads your project file
and automatically finds the location of the tools.

If you're using a source version of UE, or have installed in a non-standard location,
you can define the following environment variables instead:

* **UE4ROOT** : Set the root directory of installed versions of UE4 (instead of the default e.g. C:\Program Files\Epic Games). The script will find the correct version in subfolders e.g. UE_4.25
* **UE4INSTALL**: Explicitly set the location of the UE4 build you want to use.
    The script will just use this directly and assume it contains e.g. Engine/Build/BatchFiles


