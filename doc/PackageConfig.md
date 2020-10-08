# The packageconfig.json File

## Overview

Many of the tools in this repo, such as `ue4-package.ps1` and `ue4-release.ps1`
depend on a configuration file `packageconfig.json`.

This file should be in the root of your UE4 project. Details of its contents
are below, but here's an example demonstrating many of the features:

```json
{
    "OutputDir": "C:\\Users\\Steve\\Projects\\Builds\\Game1",
    "ZipDir": "C:\\Users\\Steve\\Projects\\Archives",

    "Target": "Game1",
    "CookAllMaps": true,    
    "MapsExcluded": [
        "TestMap",
    ],
    "UsePak": true,

    "DefaultVariants": [
        "Win64Private",
        "Win64Itch",
        "Win64Steam"
    ],

    "Variants": [
        {
            "Name": "Win64Private", 
            "Platform": "Win64",
            "Configuration": "Development",
            "ExtraBuildArguments": "-EnableDebugPanel",
            "Zip": true
        },
        {
            "Name": "Win64Steam", 
            "Platform": "Win64",
            "Configuration": "Shipping",
            "ReleaseTo": [
                "Steam"
            ],
            "SteamAppId": "783465",
            "SteamDepotId": "1238594",
            "SteamLogin": "MySteamLogin",
            "ExtraBuildArguments": "-EnableSteamworks"
        },
        {
            "Name": "Win64Itch", 
            "Platform": "Win64",
            "Configuration": "Shipping",
            "ReleaseTo": [
                "Itch"
            ],
            "ItchAppId": "my-itch-user/game1",
            "ItchChannel": "win64"
        }
    ],
}

```

## Overall File Structure

The `packageconfig.json` has 2 main parts:

* Global properties
* A list of Variants

Variants are there to allow you to build / package for multiple scenarios, such as
builds for your private use, builds for certain stores, different platforms, and so on.

Global properties apply everywhere, whilst properties contained in each Variant section
apply only to that specific build variant.

## Global Properties

### `OutputDir` 
*Mandatory Setting - string*

This is the root folder in which packaged games are placed. 
Subfolders will be created for version numbers and variants, see the [Packaging Script docs](Package.md)
for more information.

### `Target`
*Mandatory Setting - string*

The name of the target which you will package, which is usually your game name
and often the same name as the `.uproject` file.

### `Variants`
*Mandatory Setting - array of [PackageVariants](#package-variants)*

This list is where you define the way you want to package your game. See
the of [PackageVariant](#package-variants) documentation below for more details.


### `CookAllMaps`
*Optional Setting - boolean: Default=true*

If true, all `.umap` files in your Content folder will be added to the list to
cook when packaging. You can exclude some using the [`MapsExcluded`](#mapsexcluded)
option if you need to.

If false, only maps listed in [`MapsIncluded`](#mapsincluded) will be cooked.

### `MapsExcluded`
*Optional Setting - array of strings*

If [`CookAllMaps`](#cookallmaps) is true, any maps named in this array will be
excluded from the cooking process. Do not include the folder name or extension of
the map file, just the map name.

### `MapsIncluded`
*Optional Setting - array of strings*

If [`CookAllMaps`](#cookallmaps) is false, the only maps that will be cooked are
those explicitly listed in this array. Do not include the folder name or extension of
the map file, just the map name.

### `DefaultVariants`
*Optional Setting - array of strings*

This is a list of [Variant](#package-variant) names - unless otherwise specified on the command line,
this is the set of variants which will be packaged by the [Packaging Script](Package.md).
This just makes it faster / less error prone to perform your regular packaging tasks.

### `UsePak`
*Optional Setting - boolean: Default=true*

If true, combine packaged files into a .pak file.

### `ZipDir`
*Optional Setting - string* 

For variants which enable the [`Zip`](#zip) option, this is the directory that
zipped packages will be created in.

### `ProjectFile`
*Optional Setting - string* 

By default, scripts will locate your `.uproject` file automatically in the root of
your UE4 project folder. If for any reason you have more than one, you can 
specify which to use with this setting.

## Package Variants

The [`Variants`](#variants) property contains a list of ways you want to 
build and package your game. You can specify the [default list](#defaultvariants) of variants you
want to package, or name one or more on the command line explicitly.

 Each entry has these properties:



