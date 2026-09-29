# Medieval Forge launcher for Windows 11
# Keep this file next to "Medieval Launcher.cmd".

$ErrorActionPreference = 'Stop'
$Repo = 'D4skich/Medieval-updates'
$ReleaseBase = "https://github.com/$Repo/releases/latest/download"
$MinecraftDir = Join-Path $env:APPDATA '.minecraft'
$GameDir = Join-Path $MinecraftDir 'Medieval Forge'
$ManifestPath = Join-Path $GameDir '.medieval-launcher.json'
$ForgeVersion = '47.4.13'
$ForgeId = "1.20.1-forge-$ForgeVersion"

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Java {
    $java = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($java) { return $java.Source }

    $runtime = Join-Path $MinecraftDir 'runtime'
    if (Test-Path -LiteralPath $runtime) {
        $found = Get-ChildItem -LiteralPath $runtime -Filter javaw.exe -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($found) { return $found }
    }
    return $null
}

function Install-Forge {
    $versionFile = Join-Path $MinecraftDir "versions\$ForgeId\$ForgeId.json"
    if (Test-Path -LiteralPath $versionFile) { return }

    $java = Get-Java
    if (-not $java) {
        throw "Java 17 не найден. Откройте Minecraft Launcher, один раз запустите Minecraft 1.20.1, затем повторите. Если это не помогло, установите Temurin 17."
    }

    $installer = Join-Path $env:TEMP "forge-$ForgeVersion-installer.jar"
    $url = "https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-$ForgeVersion/forge-1.20.1-$ForgeVersion-installer.jar"
    Write-Host 'Устанавливаю Forge 47.4.13...'
    Invoke-WebRequest -Uri $url -OutFile $installer
    & $java '-jar' $installer '--installClient'
    if ($LASTEXITCODE -ne 0) { throw "Forge installer завершился с кодом $LASTEXITCODE." }
}

function Set-MinecraftProfile {
    $profilesPath = Join-Path $MinecraftDir 'launcher_profiles.json'
    if (-not (Test-Path -LiteralPath $profilesPath)) {
        Write-Warning 'Не найден launcher_profiles.json. Один раз откройте официальный Minecraft Launcher и запустите скрипт снова.'
        return
    }

    $profiles = Get-Content -LiteralPath $profilesPath -Raw | ConvertFrom-Json -AsHashtable
    if (-not $profiles.ContainsKey('profiles')) { $profiles['profiles'] = @{} }

    $profiles['profiles']['medieval-forge'] = @{
        name          = 'Medieval Forge'
        type          = 'custom'
        created       = (Get-Date).ToUniversalTime().ToString('o')
        lastUsed      = (Get-Date).ToUniversalTime().ToString('o')
        icon          = 'Furnace'
        lastVersionId = $ForgeId
        gameDir       = $GameDir
    }

    $profiles | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $profilesPath -Encoding UTF8
}

Write-Host 'Проверяю обновления Medieval Forge...'
$manifestUrl = "$ReleaseBase/manifest.json"
try {
    $manifest = Invoke-RestMethod -Uri $manifestUrl
} catch {
    throw "Не удалось загрузить manifest.json. Опубликуйте первый Release в $Repo."
}

if ($manifest.minecraftVersion -ne '1.20.1' -or $manifest.forgeVersion -ne $ForgeVersion) {
    throw 'Получена несовместимая версия сборки.'
}

$installed = $null
if (Test-Path -LiteralPath $ManifestPath) {
    try { $installed = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json } catch {}
}

if (-not $installed -or $installed.sha256 -ne $manifest.sha256) {
    $archive = Join-Path $env:TEMP $manifest.zipFile
    $staging = Join-Path $env:TEMP ("medieval-stage-" + [guid]::NewGuid().ToString())
    try {
        Write-Host "Скачиваю обновление $($manifest.version)..."
        Invoke-WebRequest -Uri "$ReleaseBase/$($manifest.zipFile)" -OutFile $archive
        if ((Get-Sha256 $archive) -ne $manifest.sha256.ToLowerInvariant()) {
            throw 'Проверка целостности не пройдена. Файл не будет установлен.'
        }

        New-Item -ItemType Directory -Path $staging | Out-Null
        Expand-Archive -LiteralPath $archive -DestinationPath $staging -Force
        New-Item -ItemType Directory -Path $GameDir -Force | Out-Null

        foreach ($name in $manifest.managedPaths) {
            $target = Join-Path $GameDir $name
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Recurse -Force
            }
            $source = Join-Path $staging $name
            if (Test-Path -LiteralPath $source) {
                Move-Item -LiteralPath $source -Destination $GameDir -Force
            }
        }

        $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
        Write-Host 'Сборка установлена.'
    } finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
        if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    }
} else {
    Write-Host "Установлена актуальная версия $($manifest.version)."
}

Install-Forge
Set-MinecraftProfile
Write-Host ''
Write-Host 'Готово. Откройте официальный Minecraft Launcher, выберите профиль Medieval Forge и нажмите «Играть».'
