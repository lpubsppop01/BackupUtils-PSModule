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
    $creationTime = (Get-Item -LiteralPath $srcPath).CreationTime
    $lastWriteTime = (Get-Item -LiteralPath $srcPath).LastWriteTime
    Copy-Item -LiteralPath $srcPath $destPath
    (Get-Item -LiteralPath $destPath).CreationTime = $creationTime
    (Get-Item -LiteralPath $destPath).LastWriteTime = $lastWriteTime
}

function Copy-FilesWithTimestamp($srcPath, $destPath, $srcPathsToIgnore) {
    if ((Get-Item -LiteralPath $srcPath).PSIsContainer) {
        $args = "/MIR `"$srcPath`" `"$destPath`""
        if ($srcPathsToIgnore -ne $null) {
            foreach ($path in $srcPathsToIgnore) {
                $args += " /XD `"$path`""
            }
        }
        $process = Start-Process robocopy -ArgumentList $args -NoNewWindow -PassThru -Wait
        if ($process.ExitCode -eq 0) {
            Write-Host $message_NoChange $srcPath
        } else {
            Write-Host $message_Done $srcPath
        }
    } else {
        if (!(Test-Path -LiteralPath $destPath) -or
            ((Get-Item -LiteralPath $srcPath).LastWriteTime -gt (Get-Item -LiteralPath $destPath).LastWriteTime)) {
            Copy-FileWithTimestamp $srcPath $destPath
            Write-Host $message_Done $srcPath
        } else {
            Write-Host $message_NoChange $srcPath
        }
    }
}

function Backup-Files {
    [CmdletBinding()]
    Param(
        [string] $srcBasePath,
        [string] $srcRelPath = "",
        [string[]] $srcRelPathsToIgnore = $null
    )
    PROCESS {
        if (!(Test-Path $backupDestRootDir)) {
            Write-Host $message_Error $backupDestRootDir
            return
        }
        $srcPathsToIgnore = @()
        if ($srcRelPathsToIgnore -ne $null) {
            foreach ($relPath in $srcRelPathsToIgnore) {
                $srcPathsToIgnore += Join-Path $srcBasePath $relPath
            }
        }
        if ($srcRelPath -eq "") {
            $srcPath = $srcBasePath
            if (!(Test-Path $srcPath)) {
                Write-Host $message_Error $srcPath
                return
            }
            $destPath = Join-Path $backupDestRootDir ($hostname + $glueChar + (Get-SanitizedFilename $srcPath))
            Copy-FilesWithTimestamp $srcPath $destPath $srcPathsToIgnore
        } else {
            $srcPath = Join-Path $srcBasePath $srcRelPath
            if (!(Test-Path -LiteralPath $srcPath)) {
                Write-Host $message_Error $srcPath
                return
            }
            $destBaseDirName = $hostname + $glueChar + (Get-SanitizedFilename $srcBasePath)
            $destBaseDir = Join-Path $backupDestRootDir $destBaseDirName
            $destPath = Join-Path $destBaseDir $srcRelPath
            $destParentDir = Split-Path -Parent $destPath
            if (!(Test-Path -LiteralPath $destParentDir)) {
                mkdir $destParentDir > $null
            }
            Copy-FilesWithTimestamp $srcPath $destPath $srcPathsToIgnore
        }
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

$tf_vs2017 = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer\TF.exe"
$tf_vs2015 = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\TF.exe"
$tf_vs2013 = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\TF.exe"

function Get-TfPath($altPath) {
    if ($altPath -ne $null) {
        return $altPath
    } elseif (Test-Path $tf_vs2017) {
        return $tf_vs2017
    } elseif (Test-Path $tf_vs2015) {
        return $tf_vs2015
    } elseif (Test-Path $tf_vs2013) {
        return $tf_vs2013
    }
}

function Save-TfsLocalChangesAsShelveset($srcPath=$null, $altTfPath=$null) {
    $shelvesetName = $hostname + $glueChar + (Get-SanitizedFilename $srcPath)
    $statusOutput = (&(Get-TfPath $altTfPath) status /recursive $srcPath) 2> $null
    if ($LASTEXITCODE -eq 0) {
        if ($statusOutput -match "-------------------------------------------------------------------------------") {
            &(Get-TfPath $altTfPath) shelve /replace /recursive /noprompt $shelvesetName $srcPath > $null 2> $null
        } else {
            &(Get-TfPath $altTfPath) shelve /delete /noprompt $shelvesetName > $null 2> $null
        }
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Host $message_Done $srcPath
    } else {
        Write-Host $message_Error $srcPath
    }
}

Export-ModuleMember -Variable backupDestRootDir
Export-ModuleMember -Function Backup-Files
Export-ModuleMember -Function Get-FirefoxProfileDirName
Export-ModuleMember -Function Backup-FirefoxBookmarksHTML
Export-ModuleMember -Function Backup-GoogleChromeBookmarksJSON
Export-ModuleMember -Function Save-ChocolateyInstalledPackageList
Export-ModuleMember -Function Save-NPMGlobalInstalledPackageList
Export-ModuleMember -Function Save-TfsLocalChangesAsShelveset
