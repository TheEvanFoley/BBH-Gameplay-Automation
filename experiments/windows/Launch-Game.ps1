[CmdletBinding()]
param(
    [string]$ConfigPath = ".\experiments\windows\game-launch.local.json",
    [switch]$InspectAfterLaunch,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-LauncherConfig {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\game-launch.local.json"),
        (Join-Path $repoRoot "experiments\windows\game-launch.example.json")
    )

    foreach ($candidate in $candidatePaths) {
        if (-not $candidate) {
            continue
        }

        $resolvedCandidate = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($candidate)
        if (Test-Path -LiteralPath $resolvedCandidate) {
            return $resolvedCandidate
        }
    }

    throw "No launch config found. Create experiments\windows\game-launch.local.json from the example file."
}

function Get-ConfigValue {
    param(
        $Config,
        [string]$PropertyName,
        $DefaultValue = $null
    )

    $property = $Config.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

function Start-SteamLaunch {
    param(
        [string]$SteamExePath,
        [string]$SteamAppId,
        [switch]$WhatIfMode
    )

    if (-not $SteamAppId) {
        throw "Steam launch requires steamAppId in the config."
    }

    if (-not $SteamExePath) {
        $SteamExePath = "C:\Program Files (x86)\Steam\steam.exe"
    }

    if (-not (Test-Path -LiteralPath $SteamExePath)) {
        throw "Steam executable not found at '$SteamExePath'."
    }

    $launchArgs = "-applaunch $SteamAppId"
    Write-Host "Launch method: steam"
    Write-Host "Steam executable: $SteamExePath"
    Write-Host "Steam arguments: $launchArgs"

    if (-not $WhatIfMode) {
        Start-Process -FilePath $SteamExePath -ArgumentList $launchArgs | Out-Null
    }
}

function Start-DirectLaunch {
    param(
        [string]$ExecutablePath,
        [string]$WorkingDirectory,
        [object[]]$LaunchArguments,
        [switch]$WhatIfMode
    )

    if (-not $ExecutablePath) {
        throw "Direct launch requires executablePath in the config."
    }

    if (-not (Test-Path -LiteralPath $ExecutablePath)) {
        throw "Game executable not found at '$ExecutablePath'."
    }

    if (-not $WorkingDirectory) {
        $WorkingDirectory = Split-Path -Parent $ExecutablePath
    }

    $argumentList = @($LaunchArguments | Where-Object { $null -ne $_ -and $_ -ne "" })
    Write-Host "Launch method: direct"
    Write-Host "Executable: $ExecutablePath"
    Write-Host "Working directory: $WorkingDirectory"
    Write-Host "Arguments: $($argumentList -join ' ')"

    if (-not $WhatIfMode) {
        if ($argumentList.Count -gt 0) {
            Start-Process -FilePath $ExecutablePath -WorkingDirectory $WorkingDirectory -ArgumentList $argumentList | Out-Null
        }
        else {
            Start-Process -FilePath $ExecutablePath -WorkingDirectory $WorkingDirectory | Out-Null
        }
    }
}

$resolvedConfigPath = Resolve-LauncherConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$preferredMethod = Get-ConfigValue -Config $config -PropertyName "preferredMethod" -DefaultValue "steam"
$postLaunchWaitSeconds = [int](Get-ConfigValue -Config $config -PropertyName "postLaunchWaitSeconds" -DefaultValue 10)
$surfaceNamePattern = Get-ConfigValue -Config $config -PropertyName "surfaceNamePattern" -DefaultValue "Buck|Hunter|Reloaded|Ultimate Trophy"

Write-Host "Using config: $resolvedConfigPath"

switch ($preferredMethod.ToLowerInvariant()) {
    "steam" {
        Start-SteamLaunch `
            -SteamExePath (Get-ConfigValue -Config $config -PropertyName "steamExePath") `
            -SteamAppId (Get-ConfigValue -Config $config -PropertyName "steamAppId") `
            -WhatIfMode:$DryRun
    }
    "direct" {
        Start-DirectLaunch `
            -ExecutablePath (Get-ConfigValue -Config $config -PropertyName "executablePath") `
            -WorkingDirectory (Get-ConfigValue -Config $config -PropertyName "workingDirectory") `
            -LaunchArguments (Get-ConfigValue -Config $config -PropertyName "launchArguments" -DefaultValue @()) `
            -WhatIfMode:$DryRun
    }
    default {
        throw "Unsupported preferredMethod '$preferredMethod'. Use 'steam' or 'direct'."
    }
}

if ($DryRun) {
    Write-Host "Dry run only. No process was started."
    return
}

if ($postLaunchWaitSeconds -gt 0) {
    Write-Host "Waiting $postLaunchWaitSeconds seconds for the game to appear..."
    Start-Sleep -Seconds $postLaunchWaitSeconds
}

if ($InspectAfterLaunch) {
    $surfaceScriptPath = Join-Path $PSScriptRoot "Get-GameSurface.ps1"
    & $surfaceScriptPath -NamePattern $surfaceNamePattern
}
