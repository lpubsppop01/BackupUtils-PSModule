# BackupUtils PowerShell Module

This PowerShell module provides cmdlets for backup.

## Features
- Variables:
    - `backupDestRootDir`
- Cmdlets:
    - `Backup-Files`
        - If `srcBasePath` and `srcRelPath` passed, then create base destination directory under the `backupDestRootDir`, and replicate the relative part under the base directory.
        - If only `srcBasePath` passed, then replicate the base file or directory just under the `backupDestRootDir`.
        - The destination base file or directory name is constructed by `hostname` + sanitized `srcBasePath`, to avoid collision.
    - `Get-FirefoxProfileDirName`
        - Firefox profile directory name like `xxxxxxxx.default`.
    - `Backup-FirefoxBookmarksHTML`
        - Backup `%AppData%\Mozilla\Firefox\Profiles\xxxxxxxx.default\bookmarks.html`
        - Require `browser.bookmarks.autoExportHTML` is `true`.
    - `Backup-GoogleChromeBookmarksJSON`
        - Backup `%LocalAppData%\Google\Chrome\User Data\Default\Bookmarks`.
    - `Save-ChocolateyInstalledPackageList`
        - Save Chocolatey installed package list to `$(MyDocuments)\ConfigDumps\chocolatey\packages.config`.
    - `Save-NPMGlobalInstalledPackageList`
        - Save npm global installed package list to `$(MyDocuments)\ConfigDumps\npm\ls.txt`.

## Examples
```powershell
Import-Module BackupUtils
$backupDestRootDir = "F:\Backups"

# Documents
$myDocs = [Environment]::GetFolderPath("MyDocuments")
Backup-Files $myDocs "ConfigDumps"
Backup-Files $myDocs "Visual Studio 2017\Projects"
Backup-Files $myDocs "Visual Studio 2017\Settings"
Backup-Files $myDocs "WindowsPowerShell"

# Bookmarks
$favorites = ([Environment]::GetFolderPath("Favorites"))
Backup-Files $favorites
Backup-FirefoxBookmarksHTML
Backup-GoogleChromeBookmarksJSON
```

## Installation
```powershell
PS> cd (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "WindowsPowerShell\Modules")
PS> git clone https://github.com/lpubsppop01/BackupUtils-PSModule.git BackupUtils
```

## Author
[lpubsppop01](https://github.com/lpubsppop01)

## License
[MIT License](https://github.com/lpubsppop01/BackupUtils-PSModule/raw/master/LICENSE.txt)
