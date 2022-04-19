# Release Script

The release script `ue-release.ps1` takes previously packaged builds (see
[Packaging Script](./Package.md)) and uploads them to publishing services; 
currently Itch.io and Steam.

You will need to install the [Steamworks SDK](https://partner.steamgames.com/doc/sdk)
to release on Steam, and the [Itch Butler tool](https://itch.io/docs/butler/) to
release on Itch.

This script uses configuration stored in [`packageconfig.json`](./PackageConfig.md).

```
  ue-release.ps1 [-version:ver|-latest] -variants:v1,v2 -services:steam,itch [-src:sourcefolder] [-dryrun]

  -version:ver        : Version to release; must have been packaged already
  -latest             : Instead of an explicit version, release one identified in project settings  
  -variants:var1,var2 : Name of variants to release. Omit to use DefaultVariants
  -services:s1,s2     : Name of services to release to. Can omit and rely on ReleaseTo
                        setting of variant in packageconfig.json
  -src                : Source folder (current folder if omitted), must contain packageconfig.json
  -dryrun             : Don't perform any actual actions, just report what would happen
  -help               : Print this help
```


## Uploading all builds at once

The only mandatory argument is the version number, which you can specify explicitly, 
or use the `-latest` option to take the version from project settings. With only that argument, 
the script will process all the [default variants](./PackageConfig.md#defaultvariants)
for this project and release any which have [release settings](./PackageConfig.md#defaultvariants).
This allows you to push all your builds for a given version at once.

## Uploading more selectively

Alternatively you can limit the packages you upload using the `-variants` and
`-services` arguments; if supplied, only matching variants and publishing services
will be processed.

## Authentication

This script will call the Itch `butler` tool and/or the Steam `steamcmd` tool. 
These have their own authentication; you will be prompted as needed but if you
want to guarantee no prompts during running, you should log in to the services
on the command line beforehand.

### Logging in to Itch

```
butler login
```

Your Itch authentication will be stored for future use after logging in.

### Logging in to Steam

```
steamcmd +login user_name
```

The `SteamLogin` setting in [`packageconfig.json`](./PackageConfig.md)
should be the same as the username you log in with here.

## When builds go live

There is some variation on when players can see your uploaded packages:

* **Itch**: Packages go live as soon as Itch finishes processing them
* **Steam**: Packages sit in the release queue until you explicitly release them
  via the Steamworks web interface
