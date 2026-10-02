# Sincroniza o save do Dark Souls II (SotFS) com github.com/gabrielscholze-r/DARKSOUL2
# Uso: darksouls pull | darksouls push
param([string]$Command)

$ErrorActionPreference = 'Stop'

$RepoDir        = Split-Path -Parent $PSScriptRoot   # o repo é a pasta acima de \windows
$SaveName       = 'DS2SOFS0000.sl2'
$SteamId        = '01100001437d1b30'
$SaveDir        = Join-Path $env:APPDATA "DarkSoulsII\$SteamId"
$LocalBackupDir = Join-Path $RepoDir 'backups'      # ignorado pelo git

function Die($msg) { Write-Host "erro: $msg" -ForegroundColor Red; exit 1 }

function Run-Git {
    & git -C $RepoDir @args
    if ($LASTEXITCODE -ne 0) { Die "git $($args -join ' ') falhou." }
}

function Check-GameClosed {
    if (Get-Process -Name 'DarkSoulsII' -ErrorAction SilentlyContinue) {
        Die 'feche o Dark Souls II antes de sincronizar o save.'
    }
}

function Pull {
    Check-GameClosed
    Run-Git fetch origin master
    Run-Git reset --hard origin/master
    $remote = Join-Path $RepoDir $SaveName
    if (-not (Test-Path $remote)) { Die 'save não encontrado no repo.' }

    $local = Join-Path $SaveDir $SaveName
    # Guarda uma cópia do save local antes de sobrescrever
    if (Test-Path $local) {
        New-Item -ItemType Directory -Force -Path $LocalBackupDir | Out-Null
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item $local (Join-Path $LocalBackupDir "DS2SOFS0000-$stamp.sl2")
        Get-ChildItem $LocalBackupDir -Filter *.sl2 | Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 10 | Remove-Item   # mantém os 10 mais recentes
    }

    New-Item -ItemType Directory -Force -Path $SaveDir | Out-Null
    Copy-Item $remote $local -Force
    $last = & git -C $RepoDir log -1 --format='%h %s'
    Write-Host "Save local substituído pelo do GitHub ($last)." -ForegroundColor Green
}

function Push {
    Check-GameClosed
    $local = Join-Path $SaveDir $SaveName
    if (-not (Test-Path $local)) { Die "save local não encontrado em $SaveDir" }
    Copy-Item $local (Join-Path $RepoDir $SaveName) -Force
    Run-Git add $SaveName
    & git -C $RepoDir diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Save remoto já está igual ao local, nada a enviar.'
    } else {
        Run-Git commit -q -m "save $(Get-Date -Format 'dd-MM-yyyy HH:mm')"
    }
    Run-Git push --force origin HEAD:master
    Write-Host 'Save local enviado para o GitHub.' -ForegroundColor Green
}

switch ($Command) {
    'pull'  { Pull }
    'push'  { Push }
    default { Write-Host 'uso: darksouls {pull|push}'; exit 1 }
}
