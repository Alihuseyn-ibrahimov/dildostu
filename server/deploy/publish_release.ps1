# DilDostu — yeni APK buraxılışını serverə göndərir (app-daxili yeniləmə üçün).
#
# İstifadə: dildostu\app-də pubspec.yaml-ın `version:` sətrini artırıb
# build_apk.bat ilə yeni APK qurduqdan sonra, bu skripti işə salın:
#
#   .\publish_release.ps1
#   .\publish_release.ps1 -Notes "Rutin öyrənmə əlavə olundu"
#
# pubspec.yaml-dan versiyanı avtomatik oxuyur (əl ilə versiya yazmağa ehtiyac yoxdur).

param(
    [string]$Notes = "",
    [string]$Server = "root@68.183.210.59",
    [string]$RemoteDir = "/opt/dildostu/server/releases"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$appDir = Join-Path $repoRoot "app"
$pubspecPath = Join-Path $appDir "pubspec.yaml"
$apkPath = Join-Path $appDir "build\app\outputs\flutter-apk\app-debug.apk"

if (-not (Test-Path $apkPath)) {
    Write-Error "APK tapılmadı: $apkPath`nƏvvəlcə build_apk.bat ilə qurun."
    exit 1
}

$versionLine = Get-Content $pubspecPath | Where-Object { $_ -match '^version:\s*(\S+)' }
if (-not $versionLine) {
    Write-Error "pubspec.yaml-da 'version:' sətri tapılmadı."
    exit 1
}
$versionName = ($versionLine -replace '^version:\s*', '').Trim()
if ($versionName -notmatch '\+(\d+)$') {
    Write-Error "Versiya formatı gözlənilmir (X.Y.Z+N): $versionName"
    exit 1
}
$versionCode = [int]$Matches[1]

Write-Output "Buraxılış: version_code=$versionCode, version_name=$versionName"

$tmpJson = Join-Path $env:TEMP "dildostu_version.json"
$json = @{
    version_code = $versionCode
    version_name = $versionName
    notes        = $Notes
} | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText($tmpJson, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Output "Serverə göndərilir (${Server}:${RemoteDir})..."
ssh $Server "mkdir -p $RemoteDir"
scp $apkPath "${Server}:${RemoteDir}/latest.apk"
scp $tmpJson "${Server}:${RemoteDir}/version.json"

Remove-Item $tmpJson -Force

Write-Output "Hazırdır. Telefon proqramı açanda avtomatik aşkarlayacaq."
