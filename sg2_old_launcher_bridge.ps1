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
$P2PExe = Join-Path $GameDir 'PortalWars2\Binaries\Win64\PortalWars2-Win64-Shipping.exe'
$Backup = "$P2PExe.p2p-backup"

function Show-Status {
    Write-Host "Game directory: $GameDir"
    Write-Host "Launcher:       $Launcher"
    Write-Host "Steam target:   $P2PExe"
    Write-Host "Backup:         $Backup"
    Write-Host ''

    if (-not (Test-Path -LiteralPath $Launcher -PathType Leaf)) {
        Write-Host 'Historical launcher: MISSING' -ForegroundColor Red
    } else {
        Write-Host 'Historical launcher: FOUND' -ForegroundColor Green
    }

    if (Test-Path -LiteralPath $Backup -PathType Leaf) {
        Write-Host 'P2P backup:           PRESENT' -ForegroundColor Green
    } else {
        Write-Host 'P2P backup:           absent'
    }

    if (Test-Path -LiteralPath $P2PExe) {
        $item = Get-Item -LiteralPath $P2PExe -Force
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

    if (-not (Test-Path -LiteralPath $P2PExe)) {
        throw "Current P2P executable not found: $P2PExe"
    }

    if (Test-Path -LiteralPath $P2PExe -PathType Container) {
        throw "Expected executable path is a directory: $P2PExe"
    }

    if (Test-Path -LiteralPath $Backup) {
        throw "Backup already exists: $Backup`nRefusing to overwrite it. Run 'restore' first if you need to reset the bridge."
    }

    $item = Get-Item -LiteralPath $P2PExe -Force
    if ($item.LinkType) {
        throw "Steam target is already a link ($($item.LinkType)). Refusing to overwrite it: $P2PExe"
    }

    Write-Host 'Backing up the current P2P executable...' -ForegroundColor Cyan
    Move-Item -LiteralPath $P2PExe -Destination $Backup

    try {
        Write-Host 'Creating launcher bridge...' -ForegroundColor Cyan
        $relativeTarget = '..\..\..\..\launcher.exe'
        New-Item -ItemType SymbolicLink -Path $P2PExe -Target $relativeTarget | Out-Null
    } catch {
        Write-Host 'Bridge creation failed; restoring the P2P executable...' -ForegroundColor Yellow
        if (Test-Path -LiteralPath $P2PExe) {
            Remove-Item -LiteralPath $P2PExe -Force
        }
        Move-Item -LiteralPath $Backup -Destination $P2PExe
        throw
    }

    Write-Host 'Old launcher bridge installed successfully.' -ForegroundColor Green
}

function Restore-Bridge {
    if (-not (Test-Path -LiteralPath $Backup -PathType Leaf)) {
        throw "P2P backup not found: $Backup"
    }

    if (Test-Path -LiteralPath $P2PExe) {
        $item = Get-Item -LiteralPath $P2PExe -Force
        if (-not $item.LinkType) {
            throw "Steam target is a regular file, not the bridge symlink. Refusing to overwrite it: $P2PExe"
        }
        Remove-Item -LiteralPath $P2PExe -Force
    }

    Move-Item -LiteralPath $Backup -Destination $P2PExe
    Write-Host 'Original P2P executable restored successfully.' -ForegroundColor Green
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
