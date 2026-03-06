param(
    [string]$Version = "latest",
    [string]$Repo = "shanepadgett/godotctl",
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\godotctl\bin"
)

$ErrorActionPreference = "Stop"

function Get-LatestTag {
    param([string]$Repository)
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest"
    if (-not $release.tag_name) {
        throw "failed to resolve latest release tag"
    }
    return [string]$release.tag_name
}

function Get-Arch {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    switch ($arch) {
        "X64" { return "amd64" }
        "Arm64" { return "arm64" }
        default { throw "unsupported architecture: $arch" }
    }
}

if ($Version -eq "latest") {
    $tag = Get-LatestTag -Repository $Repo
}
else {
    if ($Version.StartsWith("v")) {
        $tag = $Version
    }
    else {
        $tag = "v$Version"
    }
}

$versionNoV = $tag.TrimStart("v")
$archName = Get-Arch
$assetName = "godotctl_${versionNoV}_windows_${archName}.zip"
$checksumsName = "checksums.txt"
$releaseUrl = "https://github.com/$Repo/releases/download/$tag"

$tempRoot = Join-Path $env:TEMP ("godotctl-install-" + [guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $tempRoot $assetName
$checksumsPath = Join-Path $tempRoot $checksumsName
$extractPath = Join-Path $tempRoot "extract"

New-Item -ItemType Directory -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Path $extractPath | Out-Null

try {
    Invoke-WebRequest -Uri "$releaseUrl/$assetName" -OutFile $archivePath
    Invoke-WebRequest -Uri "$releaseUrl/$checksumsName" -OutFile $checksumsPath

    $expectedLine = Get-Content $checksumsPath | Where-Object { $_ -match "\s$([regex]::Escape($assetName))$" } | Select-Object -First 1
    if (-not $expectedLine) {
        throw "failed to find checksum entry for $assetName"
    }

    $expectedHash = ($expectedLine -split "\s+")[0].ToLowerInvariant()
    $actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expectedHash -ne $actualHash) {
        throw "checksum mismatch for $assetName`nexpected: $expectedHash`nactual:   $actualHash"
    }

    Expand-Archive -Path $archivePath -DestinationPath $extractPath -Force

    $binary = Get-ChildItem -Path $extractPath -Recurse -File | Where-Object { $_.Name -ieq "godotctl.exe" } | Select-Object -First 1
    if (-not $binary) {
        throw "failed to locate extracted godotctl.exe"
    }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $installPath = Join-Path $InstallDir "godotctl.exe"
    Copy-Item -Path $binary.FullName -Destination $installPath -Force

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathEntries = @()
    if ($userPath) {
        $pathEntries = $userPath -split ";"
    }

    if ($pathEntries -notcontains $InstallDir) {
        $newUserPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
        Write-Host "Added $InstallDir to user PATH."
        Write-Host "Open a new terminal for PATH changes to take effect."
    }

    Write-Host "Installed godotctl.exe to $installPath"
    & $installPath version
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
