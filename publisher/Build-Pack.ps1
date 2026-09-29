param(
    [Parameter(Mandatory)]
    [string]$Version,

    [string]$SourcePath = 'C:\Users\Дастан\Desktop\FORGE_FABRIC FINAL ДЕМКА',

    [string]$OutputPath = (Join-Path $PSScriptRoot 'release')
)

$ErrorActionPreference = 'Stop'
$forgeVersion = '47.4.13'
$releaseDir = Join-Path $OutputPath $Version
$stage = Join-Path $env:TEMP ("medieval-build-" + [guid]::NewGuid().ToString())
$zipName = "medieval-forge-$Version.zip"

$excludedDirectories = @(
    '.mixin.out', '.ragdollified', '.trueadaptivemusiccache',
    'cache', 'crash-reports', 'logs', 'saves', 'screenshots',
    'local', 'essential', 'XaeroWaypoints_BACKUP240807'
)
$excludedFiles = @(
    'fabricloader.log', 'hs_err_pid12688.log', 'hs_err_pid16892.log',
    'options.txt', 'servers.dat', 'servers.dat_old', 'servers.essential.dat',
    'usercache.json', 'usernamecache.json', 'ops.json', 'whitelist.json',
    'cherishedworlds-favorites.dat'
)

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Не найдена папка сборки: $SourcePath"
}
if (Test-Path -LiteralPath $releaseDir) {
    throw "Папка релиза уже существует: $releaseDir. Укажите новую версию."
}

try {
    New-Item -ItemType Directory -Path $stage | Out-Null

    Get-ChildItem -LiteralPath $SourcePath -Force | ForEach-Object {
        if ($excludedDirectories -contains $_.Name -or $excludedFiles -contains $_.Name) {
            return
        }
        Copy-Item -LiteralPath $_.FullName -Destination $stage -Recurse -Force
    }

    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    $zipPath = Join-Path $releaseDir $zipName
    Compress-Archive -LiteralPath (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal

    $manifest = [ordered]@{
        name             = 'Medieval Forge'
        version          = $Version
        minecraftVersion = '1.20.1'
        forgeVersion     = $forgeVersion
        zipFile          = $zipName
        sha256           = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        size             = (Get-Item -LiteralPath $zipPath).Length
        managedPaths     = @(Get-ChildItem -LiteralPath $stage -Force | Select-Object -ExpandProperty Name)
    }

    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $releaseDir 'manifest.json') -Encoding UTF8
    Write-Host ''
    Write-Host "Готово: $releaseDir"
    Write-Host "Создайте GitHub Release с тегом v$Version и загрузите:"
    Write-Host "  $zipName"
    Write-Host '  manifest.json'
} finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
