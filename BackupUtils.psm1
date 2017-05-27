# MyBackup.psm1

$backupDestRootDir = "*** backupDestRootDir is not set. ***"

$hostname = (hostname)
$glueChar = "_"

$message_Error =    "Error     :"
$message_Done =     "Done      :"
$message_NoChange = "No Change :"

function Get-SanitizedFilename($filename) {
    return $filename -replace "\\|/|:|\*|\?|`"|<|>|\|| ", $glueChar
}

function Copy-FileWithTimestamp($srcPath, $destPath) {
    $creationTime = (Get-Item $srcPath).CreationTime
    $lastWriteTime = (Get-Item $srcPath).LastWriteTime
    Copy-Item $srcPath $destPath
    (Get-Item $destPath).CreationTime = $creationTime
    (Get-Item $destPath).LastWriteTime = $lastWriteTime
}

function Copy-FilesWithTimestamp($srcPath, $destPath) {
    if ((Get-Item $srcPath).PSIsContainer) {
        robocopy /mir $srcPath $destPath > $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host $message_NoChange $srcPath
        } else {
            Write-Host $message_Done $srcPath
        }
    } else {
        if (!(Test-Path $destPath) -or
            ((Get-Item $srcPath).LastWriteTime -gt (Get-Item $destPath).LastWriteTime)) {
            Copy-FileWithTimestamp $srcPath $destPath
            Write-Host $message_Done $srcPath
        } else {
            Write-Host $message_NoChange $srcPath
        }
    }
}

function Backup-Files($srcBasePath, $srcRelPath=$null) {
    if (!(Test-Path $backupDestRootDir)) {
        Write-Host $message_Error $backupDestRootDir
        return
    }
    if ($srcRelPath -eq $null) {
        $srcPath = $srcBasePath
        if (!(Test-Path $srcPath)) {
            Write-Host $message_Error $srcPath
            return
        }
        $destPath = Join-Path $backupDestRootDir ($hostname + $glueChar + (Get-SanitizedFilename $srcPath))
        Copy-FilesWithTimestamp $srcPath $destPath
    } else {
        $srcPath = Join-Path $srcBasePath $srcRelPath
        if (!(Test-Path $srcPath)) {
            Write-Host $message_Error $srcPath
            return
        }
        $destBaseDirName = $hostname + $glueChar + (Get-SanitizedFilename $srcBasePath)
        $destBaseDir = Join-Path $backupDestRootDir $destBaseDirName
        $destPath = Join-Path $destBaseDir $srcRelPath
        $destParentDir = Split-Path -Parent $destPath
        if (!(Test-Path $destParentDir)) {
            mkdir $destParentDir > $null
        }
        Copy-FilesWithTimestamp $srcPath $destPath
    }
}

function Get-FirefoxProfileDirName() {
    $appData = [Environment]::GetFolderPath("ApplicationData")
    $item = Get-Item ($appData + "\Mozilla\Firefox\Profiles\*.default")
    if ($item -eq $null) {
        return $null
    }
    return $item.Name
}

function Backup-FirefoxBookmarksHTML() {
    $profileDirName = Get-FirefoxProfileDirName
    if ($profileDirName -ne $null) {
        $appData = [Environment]::GetFolderPath("ApplicationData")
        Backup-Files $appData "Mozilla\Firefox\Profiles\${profileDirName}\bookmarks.html"
    }
}

function Backup-GoogleChromeBookmarksJSON() {
    $localAppData = [Environment]::GetFolderPath("LocalApplicationData")
    Backup-Files $localAppData "Google\Chrome\User Data\Default\Bookmarks"
}

function Save-ChocolateyInstalledPackageList() {
    $myDocs = [Environment]::GetFolderPath("MyDocuments")
    $destDir = Join-Path $myDocs "ConfigDumps\chocolatey"
    $destPath = Join-Path $destDir "packages.config"

    if (!(Test-Path $destDir)) {
        mkdir $destDir > $null
    }

    $installedIDs = (clist -lo | Select-String '([^ ]+) [0-9\.]+' | ForEach-Object { $_.Matches.Groups[1].Value })

    Set-Content $destPath "<?xml version=""1.0""?>"
    Add-Content $destPath "<!-- Usage: cinst packages.config -->"
    Add-Content $destPath "<packages>"
    foreach ($id in $installedIDs) {
        Add-Content $destPath "  <package id=""$id"" />"
    }
    Add-Content $destPath "</packages>"
}

function Save-NPMGlobalInstalledPackageList() {
    $myDocs = [Environment]::GetFolderPath("MyDocuments")
    $destDir = Join-Path $myDocs "ConfigDumps\npm"
    $destPath = Join-Path $destDir "ls.txt"

    if (!(Test-Path $destDir)) {
        mkdir $destDir > $null
    }

    $installedIDs = npm ls -g --depth=0 | Select-String '[^ ]+ (.*)@[0-9\.]+' | ForEach-Object { $_.Matches.Groups[1].Value }

    Write-Output $null > $destPath
    foreach ($id in $installedIDs) {
        Add-Content $destPath $id
    }
}

Export-ModuleMember -Variable backupDestRootDir
Export-ModuleMember -Function Backup-Files
Export-ModuleMember -Function Get-FirefoxProfileDirName
Export-ModuleMember -Function Backup-FirefoxBookmarksHTML
Export-ModuleMember -Function Backup-GoogleChromeBookmarksJSON
Export-ModuleMember -Function Save-ChocolateyInstalledPackageList
Export-ModuleMember -Function Save-NPMGlobalInstalledPackageList
