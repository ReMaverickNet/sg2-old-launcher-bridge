# SG2 Old Launcher Bridge
# Restores the historical launcher.exe launch path for legacy Splitgate 2 builds.

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('install', 'restore', 'status')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Relaunch-Elevated {
    if (-not $PSCommandPath) {
        throw 'Unable to determine the script path for elevation.'
    }

    $argumentList = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', "`"$PSCommandPath`""
    )

    if ($Action) {
        $argumentList += $Action
    }

    Write-Host 'Administrator privileges are required. Requesting elevation...' -ForegroundColor Yellow
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentList -Verb RunAs -Wait
    exit $LASTEXITCODE
}

if (-not (Test-IsAdministrator)) {
    Relaunch-Elevated
}

function Get-SteamRoot {
    $registryPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam',
        'HKCU:\Software\Valve\Steam'
    )

    foreach ($path in $registryPaths) {
        try {
            $steamPath = (Get-ItemProperty -Path $path -Name 'InstallPath' -ErrorAction Stop).InstallPath
            if ($steamPath -and (Test-Path -LiteralPath $steamPath)) {
                return $steamPath
            }
        } catch {
            # Try the next registry location.
        }
    }

    $defaultPaths = @(
        "$env:ProgramFiles(x86)\Steam",
        "$env:ProgramFiles\Steam"
    ) | Where-Object { $_ }

    foreach ($path in $defaultPaths) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    throw 'Could not locate Steam. Set $env:STEAM_GAME_DIR to the Splitgate 2 game directory and run the script again.'
}

function Get-GameDirectory {
    if ($env:STEAM_GAME_DIR) {
        return (Resolve-Path -LiteralPath $env:STEAM_GAME_DIR).Path
    }

    return (Join-Path (Get-SteamRoot) 'steamapps\common\Splitgate 2')
}

$GameDir = Get-GameDirectory
$Launcher = Join-Path $GameDir 'launcher.exe'
$TargetDir = Join-Path $GameDir 'PortalWars2\Binaries\Win64'
$Target = Join-Path $TargetDir 'PortalWars2-Win64-Shipping.exe'
$Backup = "$Target.original-backup"
$LegacyBackup = "$Target.p2p-backup"

function Show-Status {
    Write-Host "Game directory: $GameDir"
    Write-Host "Launcher:       $Launcher"
    Write-Host "Steam target:   $Target"
    Write-Host "Backup:         $Backup"
    Write-Host ''

    if (-not (Test-Path -LiteralPath $Launcher -PathType Leaf)) {
        Write-Host 'Historical launcher: MISSING' -ForegroundColor Red
    } else {
        Write-Host 'Historical launcher: FOUND' -ForegroundColor Green
    }

    if (Test-Path -LiteralPath $Backup -PathType Leaf) {
        Write-Host 'Original backup:      PRESENT' -ForegroundColor Green
    } elseif (Test-Path -LiteralPath $LegacyBackup -PathType Leaf) {
        Write-Host 'Legacy backup:        PRESENT' -ForegroundColor Green
    } else {
        Write-Host 'Original backup:      absent'
    }

    if (Test-Path -LiteralPath $Target) {
        $item = Get-Item -LiteralPath $Target -Force
        if ($item.LinkType -eq 'SymbolicLink' -or $item.LinkType -eq 'HardLink') {
            Write-Host "Steam target:         $($item.LinkType) -> $($item.Target)" -ForegroundColor Cyan
        } else {
            Write-Host 'Steam target:         regular file'
        }
    } else {
        Write-Host 'Steam target:         MISSING' -ForegroundColor Red
    }
}

function Install-Bridge {
    if (-not (Test-Path -LiteralPath $Launcher -PathType Leaf)) {
        throw "Historical launcher not found: $Launcher"
    }

    if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $Target -PathType Container) {
        throw "Expected executable path is a directory: $Target"
    }

    if ((Test-Path -LiteralPath $Backup) -or (Test-Path -LiteralPath $LegacyBackup)) {
        $existingBackup = if (Test-Path -LiteralPath $Backup) { $Backup } else { $LegacyBackup }
        throw "Backup already exists: $existingBackup`nRefusing to overwrite it. Run 'restore' first if you need to reset the bridge."
    }

    if (Test-Path -LiteralPath $Target) {
        $item = Get-Item -LiteralPath $Target -Force
        if ($item.LinkType) {
            $resolvedTarget = $item.Target
            if ($resolvedTarget -eq '..\..\..\launcher.exe' -or $resolvedTarget -eq $Launcher) {
                Write-Host 'Bridge is already installed.' -ForegroundColor Green
                return
            }
            throw "Steam target is already a link ($($item.LinkType)). Refusing to overwrite it: $Target"
        }

        if (-not $item.PSIsContainer) {
            Write-Host 'Backing up the existing Steam target...' -ForegroundColor Cyan
            Move-Item -LiteralPath $Target -Destination $Backup
        }
    }

    try {
        Write-Host 'Creating launcher bridge...' -ForegroundColor Cyan
        $relativeTarget = '..\..\..\launcher.exe'
        New-Item -ItemType SymbolicLink -Path $Target -Target $relativeTarget | Out-Null
    } catch {
        Write-Host 'Bridge creation failed; restoring the original target...' -ForegroundColor Yellow
        if (Test-Path -LiteralPath $Target) {
            Remove-Item -LiteralPath $Target -Force
        }
        if (Test-Path -LiteralPath $Backup -PathType Leaf) {
            Move-Item -LiteralPath $Backup -Destination $Target
        }
        throw
    }

    Write-Host 'Old launcher bridge installed successfully.' -ForegroundColor Green
}

function Restore-Bridge {
    $restoreBackup = if (Test-Path -LiteralPath $Backup -PathType Leaf) { $Backup } elseif (Test-Path -LiteralPath $LegacyBackup -PathType Leaf) { $LegacyBackup } else { $null }

    if (Test-Path -LiteralPath $Target) {
        $item = Get-Item -LiteralPath $Target -Force
        if (-not $item.LinkType) {
            throw "Steam target is a regular file, not the bridge symlink. Refusing to overwrite it: $Target"
        }
        Remove-Item -LiteralPath $Target -Force
    }

    if ($restoreBackup) {
        Move-Item -LiteralPath $restoreBackup -Destination $Target
        Write-Host 'Original executable restored successfully.' -ForegroundColor Green
    } else {
        Write-Host 'Bridge removed. No backed-up executable was present.' -ForegroundColor Yellow
    }
}

if (-not $Action) {
    Write-Host 'SG2 Old Launcher Bridge' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Usage:'
    Write-Host '  .\sg2_old_launcher_bridge.ps1 install'
    Write-Host '  .\sg2_old_launcher_bridge.ps1 restore'
    Write-Host '  .\sg2_old_launcher_bridge.ps1 status'
    Write-Host ''
    Write-Host 'The script will request Administrator privileges automatically.'
    exit 0
}

switch ($Action) {
    'install' { Install-Bridge }
    'restore' { Restore-Bridge }
    'status'  { Show-Status }
}
